use anyhow::Result;

// consumes results.sensor.> and results.inference.> from nats jetstream
// batches writes to influxdb3 http api at http://localhost:8086

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt::init();
    let nats_url = std::env::var("NATS_URL").unwrap_or_else(|_| "nats://localhost:4222".into());
    let _client = shared::nats::connect(&nats_url).await?;
    tracing::info!("influx-writer connected to nats");
    // TODO: subscribe to results.> and batch write to influxdb3
    Ok(())
}
