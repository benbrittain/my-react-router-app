import { StrictMode } from "react";
import { createRoot } from 'react-dom/client';
import { BrowserRouter, Routes, Route } from "react-router";
import { App, App2 } from "./app"

const container = document.getElementById('root');
if (!container) {
  throw new Error("The root container wasn't found");
}
const root = createRoot(container);

root.render(
  <StrictMode>
    <BrowserRouter>
      <Routes>
        <Route path="/" element=<App /> />
        <Route path="/exit" element=<App2 /> />
      </Routes>
    </BrowserRouter>
  </StrictMode>
);
