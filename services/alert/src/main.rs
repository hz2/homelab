use anyhow::Result;
use tokio_stream::wrappers::ReceiverStream;
use tonic::{transport::Server, Request, Response, Status};

mod proto {
    tonic::include_proto!("alerts.v1");
}

use proto::{
    alert_service_server::{AlertService, AlertServiceServer},
    AcknowledgeRequest, AcknowledgeResponse, Alert, CreateAlertRequest, CreateAlertResponse,
    ListAlertsRequest, ListAlertsResponse,
};

struct AlertServiceImpl;

#[tonic::async_trait]
impl AlertService for AlertServiceImpl {
    async fn create_alert(
        &self,
        _req: Request<CreateAlertRequest>,
    ) -> Result<Response<CreateAlertResponse>, Status> {
        Err(Status::unimplemented("not yet implemented"))
    }

    async fn list_alerts(
        &self,
        _req: Request<ListAlertsRequest>,
    ) -> Result<Response<ListAlertsResponse>, Status> {
        Ok(Response::new(ListAlertsResponse { alerts: vec![] }))
    }

    async fn acknowledge(
        &self,
        _req: Request<AcknowledgeRequest>,
    ) -> Result<Response<AcknowledgeResponse>, Status> {
        Ok(Response::new(AcknowledgeResponse {}))
    }

    type StreamAlertsStream = ReceiverStream<Result<Alert, Status>>;

    async fn stream_alerts(
        &self,
        _req: Request<ListAlertsRequest>,
    ) -> Result<Response<Self::StreamAlertsStream>, Status> {
        let (_tx, rx) = tokio::sync::mpsc::channel(1);
        Ok(Response::new(ReceiverStream::new(rx)))
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt::init();
    let addr = "[::]:50054".parse()?;
    tracing::info!("alert listening on {addr}");
    Server::builder()
        .accept_http1(true)
        .add_service(tonic_web::enable(AlertServiceServer::new(AlertServiceImpl)))
        .serve(addr)
        .await?;
    Ok(())
}
