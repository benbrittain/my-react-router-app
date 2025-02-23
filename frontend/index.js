import React from "react";
import { createRoot } from 'react-dom/client';
import { BrowserRouter, Routes, Route } from "react-router";
import { App,App2 } from "./app"

const container = document.getElementById('root');
const root = createRoot(container);

root.render(
  <BrowserRouter>
    <Routes>
      <Route path="/" element=<App /> />
      <Route path="/exit" element=<App2 /> />
    </Routes>
  </BrowserRouter>
);
