import { useEffect } from 'react';
import { SuitSprite } from './components/Card.tsx';
import { IconSprite } from './components/Icons.tsx';
import { primeAudio } from './sound.ts';
import { useRoute } from './router.ts';
import { Home } from './screens/Home.tsx';
import { Room } from './screens/Room.tsx';
import { Challenges, Clubs, Games, Store } from './screens/Tabs.tsx';
import { Tables } from './screens/Tables.tsx';

export function App() {
  const route = useRoute();
  // browsers block audio until a real user gesture; the first tap anywhere in the app unlocks it
  useEffect(() => {
    const on = () => primeAudio();
    window.addEventListener('pointerdown', on, { once: true });
    return () => window.removeEventListener('pointerdown', on);
  }, []);
  let screen;
  switch (route.name) {
    case 'room':
      screen = <Room key={route.code} code={route.code} />;
      break;
    case 'tables':
      screen = <Tables />;
      break;
    case 'games':
      screen = <Games />;
      break;
    case 'store':
      screen = <Store />;
      break;
    case 'clubs':
      screen = <Clubs />;
      break;
    case 'challenges':
      screen = <Challenges />;
      break;
    default:
      screen = <Home />;
  }
  return (
    <>
      <SuitSprite />
      <IconSprite />
      {screen}
    </>
  );
}
