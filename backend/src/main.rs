use axum::Router;
use axum::routing::get;
use tower_http::{
    services::{ServeDir, ServeFile},
};

fn using_serve_dir() -> Router {
    let serve_dir = ServeDir::new("assets")
        .not_found_service(ServeFile::new("assets/index.html"));

    Router::new()
        .route("/foo", get(|| async { "Hi from /foo" }))
        .nest_service("/assets", serve_dir.clone())
        .fallback_service(serve_dir)

}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let app = using_serve_dir();

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await?;
    axum::serve(listener, app.into_make_service()).await?;

    Ok(())
}
