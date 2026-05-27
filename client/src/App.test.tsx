import { render, screen } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import App from './App';

vi.mock('./components/MapContainer', () => ({
  default: () => <div data-testid="map-container" />,
}));

describe('App', () => {
  let consoleLogSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    consoleLogSpy = vi.spyOn(console, 'log').mockImplementation(() => {});
  });

  afterEach(() => {
    consoleLogSpy.mockRestore();
  });

  it('renders the map container inside the app shell', () => {
    const { container } = render(<App />);
    const appShell = container.querySelector('.App');
    const mapContainer = screen.getByTestId('map-container');

    expect(appShell).toBeInTheDocument();
    expect(mapContainer).toBeInTheDocument();
    expect(appShell).toContainElement(mapContainer);
  });
});
