import { createRoot } from 'react-dom/client';
import '../../../design/tokens.css'; // approved design tokens (direction 1 «ديوانية»), owned by the designer
import './styles/app.css';
import './styles/v3.css';
import { App } from './App.tsx';

createRoot(document.getElementById('root')!).render(<App />);
