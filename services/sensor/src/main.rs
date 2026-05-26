use anyhow::Result;
use async_nats::Client;
use futures::StreamExt;
use prost_types::Timestamp;
use serde::Deserialize;
use std::{
    collections::HashMap,
    sync::Arc,
    time::{SystemTime, UNIX_EPOCH},
};
use tokio::sync::{mpsc, Mutex};
use tokio_stream::wrappers::ReceiverStream;
use tonic::{transport::Server, Request, Response, Status};

mod proto {
    tonic::include_proto!("sensor.v1");
}

use proto::{
    sensor_service_server::{SensorService, SensorServiceServer},
    ListSensorsRequest, ListSensorsResponse, SensorInfo, SensorReading, StreamReadingsRequest,
};

#[derive(Deserialize)]
struct SensorPayload {
    v: f64,
}

#[derive(Clone)]
struct SensorEntry {
    node_id: String,
    metric: String,
    last_seen: SystemTime,
}

type Registry = Arc<Mutex<HashMap<String, SensorEntry>>>;

#[derive(Clone)]
struct SensorServiceImpl {
    nats: Client,
    registry: Registry,
}

fn now_ts() -> Timestamp {
    let d = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default();
    Timestamp { seconds: d.as_secs() as i64, nanos: d.subsec_nanos() as i32 }
}

fn systime_ts(t: SystemTime) -> Timestamp {
    let d = t.duration_since(UNIX_EPOCH).unwrap_or_default();
    Timestamp { seconds: d.as_secs() as i64, nanos: d.subsec_nanos() as i32 }
}

#[tonic::async_trait]
impl SensorService for SensorServiceImpl {
    async fn list_sensors(
        &self,
        req: Request<ListSensorsRequest>,
    ) -> Result<Response<ListSensorsResponse>, Status> {
        let node_filter = req.into_inner().node_id;
        let reg = self.registry.lock().await;
        let sensors = reg
            .iter()
            .filter(|(_, e)| node_filter.is_empty() || e.node_id == node_filter)
            .map(|(key, e)| SensorInfo {
                sensor_id: key.clone(),
                node_id: e.node_id.clone(),
                r#type: e.metric.clone(),
                last_seen: Some(systime_ts(e.last_seen)),
            })
            .collect();
        Ok(Response::new(ListSensorsResponse { sensors }))
    }

    type StreamReadingsStream = ReceiverStream<Result<SensorReading, Status>>;

    async fn stream_readings(
        &self,
        req: Request<StreamReadingsRequest>,
    ) -> Result<Response<Self::StreamReadingsStream>, Status> {
        let r = req.into_inner();
        let subject = match (r.node_id.as_str(), r.sensor_id.as_str()) {
            ("", _) => "sensors.>".to_string(),
            (node, "") => format!("sensors.{node}.>"),
            (node, sid) => format!("sensors.{node}.{sid}"),
        };
        let mut sub = self
            .nats
            .subscribe(subject)
            .await
            .map_err(|e| Status::internal(e.to_string()))?;
        let (tx, rx) = mpsc::channel(32);
        tokio::spawn(async move {
            while let Some(msg) = sub.next().await {
                let parts: Vec<&str> = msg.subject.splitn(3, '.').collect();
                if parts.len() < 3 {
                    continue;
                }
                let node_id = parts[1].to_string();
                let metric = parts[2].to_string();
                let Ok(p) = serde_json::from_slice::<SensorPayload>(&msg.payload[..]) else {
                    continue;
                };
                let reading = SensorReading {
                    sensor_id: format!("{node_id}.{metric}"),
                    node_id,
                    metric,
                    value: p.v,
                    unit: String::new(),
                    timestamp: Some(now_ts()),
                };
                if tx.send(Ok(reading)).await.is_err() {
                    break;
                }
            }
        });
        Ok(Response::new(ReceiverStream::new(rx)))
    }
}

async fn run_registry(nats: Client, registry: Registry) {
    let Ok(mut sub) = nats.subscribe("sensors.>").await else {
        tracing::error!("failed to subscribe sensors.>");
        return;
    };
    while let Some(msg) = sub.next().await {
        let parts: Vec<&str> = msg.subject.splitn(3, '.').collect();
        if parts.len() < 3 {
            continue;
        }
        let node_id = parts[1].to_string();
        let metric = parts[2].to_string();
        let key = format!("{node_id}.{metric}");
        let mut reg = registry.lock().await;
        reg.entry(key).and_modify(|e| e.last_seen = SystemTime::now()).or_insert(SensorEntry {
            node_id,
            metric,
            last_seen: SystemTime::now(),
        });
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt::init();
    let nats_url = std::env::var("NATS_URL").unwrap_or_else(|_| "nats://localhost:4222".into());
    let nats = shared::nats::connect(&nats_url).await?;
    let registry: Registry = Arc::new(Mutex::new(HashMap::new()));
    tokio::spawn(run_registry(nats.clone(), registry.clone()));
    let addr = "[::]:50051".parse()?;
    tracing::info!("sensor-api listening on {addr}");
    Server::builder()
        .accept_http1(true)
        .add_service(tonic_web::enable(SensorServiceServer::new(SensorServiceImpl {
            nats,
            registry,
        })))
        .serve(addr)
        .await?;
    Ok(())
}
