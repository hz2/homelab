use anyhow::Result;

// lightweight nats queue consumer; runs on follower nodes (pi 1/2)
// subscribes to tasks.sensor.collect and tasks.io.relay

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt::init();
    let nats_url = std::env::var("NATS_URL").unwrap_or_else(|_| "nats://localhost:4222".into());
    let _client = shared::nats::connect(&nats_url).await?;
    tracing::info!("worker connected to nats");
    // TODO: subscribe to tasks.> work queue subjects
    Ok(())
}
