import { jsx as _jsx } from "react/jsx-runtime";
import { Welcome } from "../welcome/welcome";
export function meta({}) {
    return [
        { title: "New React Router App" },
        { name: "description", content: "Welcome to React Router!" },
    ];
}
export default function Home() {
    return _jsx(Welcome, {});
}
