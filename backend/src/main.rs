use axum::routing::get;
use axum::Router;
use tower_http::services::{ServeDir, ServeFile};

use buck_resources::get_resource;

fn using_serve_dir() -> Router {
    let mut asset_path = get_resource("backend/javascript_assets").unwrap();
    asset_path.push("__srcs/app");
    let serve_dir =
        ServeDir::new(asset_path).not_found_service(ServeFile::new("assets/index.html"));

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
