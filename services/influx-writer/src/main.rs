use anyhow::Result;
use async_nats::Client;
use futures::StreamExt;
use reqwest::Client as HttpClient;
use serde::Deserialize;
use std::time::{SystemTime, UNIX_EPOCH};

const INFLUX_WRITE_URL: &str = "http://localhost:8086/api/v2/write?bucket=homelab";

#[derive(Deserialize)]
struct SensorPayload {
    v: f64,
}

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

fn now_nanos() -> u128 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_nanos()
}

async fn write_line(http: &HttpClient, line: &str) {
    if let Err(e) = http
        .post(INFLUX_WRITE_URL)
        .header("Content-Type", "text/plain; charset=utf-8")
        .body(line.to_string())
        .send()
        .await
    {
        tracing::warn!("influxdb write failed: {e}");
    }
}

async fn run_sensor_writer(nats: Client, http: HttpClient) {
    let Ok(mut sub) = nats.subscribe("sensors.>").await else {
        tracing::error!("failed to subscribe sensors.>");
        return;
    };
    while let Some(msg) = sub.next().await {
        let parts: Vec<&str> = msg.subject.splitn(3, '.').collect();
        if parts.len() < 3 {
            continue;
        }
        let node = parts[1];
        let metric = parts[2];
        let Ok(p) = serde_json::from_slice::<SensorPayload>(&msg.payload[..]) else {
            continue;
        };
        let line = format!(
            "sensor,node_id={node},metric={metric} value={} {}",
            p.v,
            now_nanos()
        );
        write_line(&http, &line).await;
    }
}

async fn run_frigate_writer(nats: Client, http: HttpClient) {
    let Ok(mut sub) = nats.subscribe("frigate.>").await else {
        tracing::error!("failed to subscribe frigate.>");
        return;
    };
    while let Some(msg) = sub.next().await {
        let Ok(ev) = serde_json::from_slice::<FrigateEvent>(&msg.payload[..]) else {
            continue;
        };
        if ev.event_type != "new" {
            continue;
        }
        let ts_nanos = ev
            .after
            .start_time
            .map(|t| (t * 1e9) as u128)
            .unwrap_or_else(now_nanos);
        let confidence = ev.after.score.unwrap_or(0.0);
        let line = format!(
            "detection,camera={},label={} confidence={} {}",
            ev.after.camera, ev.after.label, confidence, ts_nanos
        );
        write_line(&http, &line).await;
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt::init();
    let nats_url = std::env::var("NATS_URL").unwrap_or_else(|_| "nats://localhost:4222".into());
    let nats = shared::nats::connect(&nats_url).await?;
    let http = HttpClient::new();
    tracing::info!("influx-writer connected to nats at {nats_url}");
    let h1 = tokio::spawn(run_sensor_writer(nats.clone(), http.clone()));
    let h2 = tokio::spawn(run_frigate_writer(nats.clone(), http.clone()));
    tokio::try_join!(h1, h2)?;
    Ok(())
}
