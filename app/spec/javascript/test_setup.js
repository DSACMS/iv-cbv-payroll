import { vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import { JSDOM } from 'jsdom';
import loadScript from "load-script";
import { mockArgyleAuthToken } from './fixtures/argyle.fixture.js';
import { mockPinwheelAuthToken } from './fixtures/pinwheel.fixture.js';

const { window } = new JSDOM();

global.window = window;
global.document = window.document;
global.Node = window.Node;


// Mock CSRF token
document.head.innerHTML = `
  <meta name="csrf-token" content="test-csrf-token">
`;

// Mock fetch API
global.fetch = vi.fn();

// Mock window.matchMedia
window.matchMedia = vi.fn().mockImplementation(query => ({
  matches: false,
  media: query,
  onchange: null,
  addListener: vi.fn(),
  removeListener: vi.fn(),
  addEventListener: vi.fn(),
  removeEventListener: vi.fn(),
  dispatchEvent: vi.fn(),
}));

vi.mock('load-script', () => {
  return {
      default: vi.fn(),
  }
})

vi.mock('@js/utilities/api', async () => {
  const apiModule = await vi.importActual('@js/utilities/api')
  return {
      ...apiModule,
      trackUserAction: vi.fn((eventName, eventPayload) => Promise.resolve()),
      fetchPinwheelToken: vi.fn(() => Promise.resolve(mockPinwheelAuthToken)),
      fetchArgyleToken: vi.fn(() => Promise.resolve(mockArgyleAuthToken)),
  }
})

// Reset all mocks before each test
beforeEach(() => {
  // Set up Stimulus
  window.Stimulus = Application.start();

  vi.clearAllMocks();
  fetch.mockReset();
});

// Clean up after each test
afterEach(() => {
  window.Stimulus.stop()
  loadScript.mockReset()
  document.head.innerHTML = `
    <meta name="csrf-token" content="test-csrf-token">
  `;
}); 