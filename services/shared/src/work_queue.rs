use anyhow::Result;

#[allow(async_fn_in_trait)]
pub trait WorkHandler: Send + Sync {
    type Task: Send;
    fn subject(&self) -> &str;
    async fn handle(&self, task: Self::Task) -> Result<()>;
}
