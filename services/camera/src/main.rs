use anyhow::Result;
use async_nats::Client;
use futures::StreamExt;
use prost_types::Timestamp;
use serde::Deserialize;
use tokio::sync::mpsc;
use tokio_stream::wrappers::ReceiverStream;
use tonic::{transport::Server, Request, Response, Status};

mod proto {
    tonic::include_proto!("camera.v1");
}

use proto::{
    camera_service_server::{CameraService, CameraServiceServer},
    Camera, DetectionEvent, ListCamerasRequest, ListCamerasResponse, SourceType,
    StreamEventsRequest,
};

#[derive(Deserialize)]
struct FrigateAfter {
    camera: String,
    label: String,
    score: Option<f64>,
    start_time: Option<f64>,
}

#[derive(Deserialize)]
struct FrigateEvent {
    #[serde(rename = "type")]
    event_type: String,
    after: FrigateAfter,
}

#[derive(Clone)]
struct CameraServiceImpl {
    nats: Client,
}

#[tonic::async_trait]
impl CameraService for CameraServiceImpl {
    async fn list_cameras(
        &self,
        _req: Request<ListCamerasRequest>,
    ) -> Result<Response<ListCamerasResponse>, Status> {
        let cameras = vec![Camera {
            camera_id: "axis".to_string(),
            name: "Axis P3245-V".to_string(),
            source_type: SourceType::Rtsp as i32,
            // frigate restream avoids needing direct camera credentials
            source_url: "rtsp://localhost:8554/axis".to_string(),
            online: true,
        }];
        Ok(Response::new(ListCamerasResponse { cameras }))
    }

    type StreamEventsStream = ReceiverStream<Result<DetectionEvent, Status>>;

    async fn stream_events(
        &self,
        req: Request<StreamEventsRequest>,
    ) -> Result<Response<Self::StreamEventsStream>, Status> {
        let camera_id = req.into_inner().camera_id;
        let subject = if camera_id.is_empty() {
            "frigate.*.events".to_string()
        } else {
            format!("frigate.{camera_id}.events")
        };
        let mut sub = self
            .nats
            .subscribe(subject)
            .await
            .map_err(|e| Status::internal(e.to_string()))?;
        let (tx, rx) = mpsc::channel(32);
        tokio::spawn(async move {
            while let Some(msg) = sub.next().await {
                let Ok(ev) = serde_json::from_slice::<FrigateEvent>(&msg.payload[..]) else {
                    continue;
                };
                // only forward "new" events to avoid duplicate alerts for the same detection
                if ev.event_type != "new" {
                    continue;
                }
                let ts = ev.after.start_time.map(|t| {
                    let secs = t as i64;
                    let nanos = ((t - secs as f64) * 1e9) as i32;
                    Timestamp { seconds: secs, nanos }
                });
                let event = DetectionEvent {
                    camera_id: ev.after.camera,
                    label: ev.after.label,
                    confidence: ev.after.score.unwrap_or(0.0) as f32,
                    timestamp: ts,
                    snapshot: vec![],
                };
                if tx.send(Ok(event)).await.is_err() {
                    break;
                }
            }
        });
        Ok(Response::new(ReceiverStream::new(rx)))
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt::init();
    let nats_url = std::env::var("NATS_URL").unwrap_or_else(|_| "nats://localhost:4222".into());
    let nats = shared::nats::connect(&nats_url).await?;
    let addr = "[::]:50052".parse()?;
    tracing::info!("camera-api listening on {addr}");
    Server::builder()
        .accept_http1(true)
        .add_service(tonic_web::enable(CameraServiceServer::new(CameraServiceImpl { nats })))
        .serve(addr)
        .await?;
    Ok(())
}
