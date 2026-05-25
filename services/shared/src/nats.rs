use anyhow::Result;

pub async fn connect(url: &str) -> Result<async_nats::Client> {
    let client = async_nats::connect(url).await?;
    Ok(client)
}

pub async fn jetstream(client: &async_nats::Client) -> async_nats::jetstream::Context {
    async_nats::jetstream::new(client.clone())
}
