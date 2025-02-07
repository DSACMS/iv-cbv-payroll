import { vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import { JSDOM } from 'jsdom';

const { window } = new JSDOM();

global.window = window;
global.document = window.document;
global.Node = window.Node;

// Set up Stimulus
window.Stimulus = Application.start();

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

// Reset all mocks before each test
beforeEach(() => {
  vi.clearAllMocks();
  fetch.mockReset();
});

// Clean up after each test
afterEach(() => {
  document.head.innerHTML = `
    <meta name="csrf-token" content="test-csrf-token">
  `;
}); 