import type * as T from "react-router/route-module";
type Module = typeof import("../root.js");
export type Info = {
    parents: [];
    id: "root";
    file: "root.tsx";
    path: "";
    params: {} & {
        [key: string]: string | undefined;
    };
    module: Module;
    loaderData: T.CreateLoaderData<Module>;
    actionData: T.CreateActionData<Module>;
};
export declare namespace Route {
    type LinkDescriptors = T.LinkDescriptors;
    type LinksFunction = () => LinkDescriptors;
    type MetaArgs = T.CreateMetaArgs<Info>;
    type MetaDescriptors = T.MetaDescriptors;
    type MetaFunction = (args: MetaArgs) => MetaDescriptors;
    type HeadersArgs = T.HeadersArgs;
    type HeadersFunction = (args: HeadersArgs) => Headers | HeadersInit;
    type LoaderArgs = T.CreateServerLoaderArgs<Info>;
    type ClientLoaderArgs = T.CreateClientLoaderArgs<Info>;
    type ActionArgs = T.CreateServerActionArgs<Info>;
    type ClientActionArgs = T.CreateClientActionArgs<Info>;
    type HydrateFallbackProps = T.CreateHydrateFallbackProps<Info>;
    type ComponentProps = T.CreateComponentProps<Info>;
    type ErrorBoundaryProps = T.CreateErrorBoundaryProps<Info>;
}
export {};
