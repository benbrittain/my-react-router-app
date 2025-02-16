import type { Route } from "./+types/home";
export declare function meta({}: Route.MetaArgs): ({
    title: string;
    name?: undefined;
    content?: undefined;
} | {
    name: string;
    content: string;
    title?: undefined;
})[];
export default function Home(): import("react/jsx-runtime").JSX.Element;
