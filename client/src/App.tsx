// App.tsx


// import MapContainer from './components/MapContainer'; // default import

// const App: React.FC = () => {
//   return <MapContainer />; // React.createElement(MapContainer, null) と同じ
// };

// export default App;



import { useEffect } from 'react';
import MapContainer from './components/MapContainer';
import './App.css';

function App() {
  useEffect(() => {
    console.log('App component mounted');
  }, []);

  return (
    <div className="App">
      <MapContainer />
    </div>
  );
}

export default App;
