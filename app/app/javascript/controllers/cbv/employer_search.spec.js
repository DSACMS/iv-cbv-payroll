import { vi, describe, beforeEach, it, expect, test } from 'vitest'
import { Application, Controller } from '@hotwired/stimulus';
import EmployerSearchController from './employer_search'

vi.mock('../../utilities/pinwheel.js', () => {
    return {
      loadPinwheel: vi.fn(),
      initializePinwheel: vi.fn(),
      trackUserAction: vi.fn(),
      fetchToken: vi.fn( () => "test-token")
    }
  })

describe('EmployerSearchController', () => {
  beforeEach(() => {
    document.body.innerHTML = "<button \
    id=\"btn\" \
    data-controller=\"cbv-employer-search\" \
    data-action=\"click->cbv-employer-search#select\" \
    data-id=\"test employer\"> Hello World \
  </button>"

    const application = Application.start();
    application.register('cbv-employer-search', EmployerSearchController);
  });

  it('shows hello world', () => {
    console.log('helo')
    
    const btn = document.getElementById('btn');
    btn.click();
    //expect(fetchToken).toHaveBeenCalled()
    //expect(document).toHaveTextContent('Hello World')
  });
})
/*
import EmployerSearchController from "../controllers/cbv/employer_search"
import { Application, Controller } from '@hotwired/stimulus';
import { fetchToken } from "../utilities/pinwheel"

jest.mock('../utilities/pinwheel')

describe('EmployerSearchController', () => {
  beforeEach(() => {
    document.body.innerHTML = "<button \
    id=\"btn\" \
    data-controller=\"cbv-employer-search\" \
    data-action=\"click->cbv-employer-search#select\" \
    data-id=\"test employer\"> Hello World \
  </button>"

    const application = Application.start();
    application.register('cbv-employer-search', EmployerSearchController);
  });

  it('shows hello world', () => {
    console.log('helo')
    
    const btn = document.getElementById('btn');
    btn.click();
    expect(fetchToken).toHaveBeenCalled()
    //expect(document).toHaveTextContent('Hello World')
  });
});


const sum = function sum(a, b) {
    return a + b;
  }

test('adds 1 + 2 to equal 3', () => {
  expect(sum(1, 2)).toBe(3);
});
*/