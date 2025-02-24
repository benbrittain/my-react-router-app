function MyButton({ title }: { title: string }) {
  return (
    <button>{title}</button>
  );
}

export default function App() {
  return (
    <div>
      <h1>Welcome to my app</h1>
      <MyButton title="Button" />
    </div>
  );
}

const App2 = () => {
  return (
    <div>Goodbyee! </div>
  );
}

export { App, App2 };
