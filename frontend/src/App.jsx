import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider, useAuth } from "./context/AuthContext";
import Login from "./pages/Login";
import Dashboard from "./pages/Dashboard";
import Chat from "./pages/Chat";
import Mood from "./pages/Mood";
import Resources from "./pages/Resources";
function Protected({ children }) {
  const { isAuth } = useAuth();
  return isAuth ? children : <Navigate to="/login" replace/>;
}
function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login/>}/>
          <Route path="/" element={<Protected><Dashboard/></Protected>}/>
          <Route path="/chat" element={<Protected><Chat/></Protected>}/>
          <Route path="/mood" element={<Protected><Mood/></Protected>}/>
          <Route path="/resources" element={<Protected><Resources/></Protected>}/>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}
export default App;
