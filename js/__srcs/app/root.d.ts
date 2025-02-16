import type { Route } from "./+types/root";
import "./app.css";
export declare const links: Route.LinksFunction;
export declare function Layout({ children }: {
    children: React.ReactNode;
}): import("react/jsx-runtime").JSX.Element;
export default function App(): import("react/jsx-runtime").JSX.Element;
export declare function ErrorBoundary({ error }: Route.ErrorBoundaryProps): import("react/jsx-runtime").JSX.Element;
