import { vi, describe, beforeEach, it, expect } from 'vitest'
import { Application, Controller } from '@hotwired/stimulus';
import EmployerSearchController from './employer_search'
import { loadPinwheel} from '../../utilities/pinwheel'
import { fetchToken } from '../../utilities/api';

vi.mock('../../utilities/pinwheel.js', async () => {
    const pinwheelModule = await vi.importActual('../../utilities/pinwheel')
    return {
        ...pinwheelModule,
        loadPinwheel: vi.fn(() => Promise.resolve({ data: {} })),
        initializePinwheel: vi.fn(() => Promise.resolve({ data: {} })),
    }
  })

describe('EmployerSearchController', () => {
  beforeEach(() => {
    document.body.innerHTML = `<button \
    id="btn" 
    data-controller="cbv-employer-search" 
    data-action="click->cbv-employer-search#select" 
    data-id="mock-employer-id"
    data-response-type="mock-employer-responsetype"
    data-name="mock-employer-name"
    data-testid="employer-search-button"
    type="button">Employee Search Button Text</button>`

    const application = Application.start();
    application.register('cbv-employer-search', EmployerSearchController);
  });

  it('shows hello world', () => {
  
  //  pinwheel.loadPinwheel.mockResolvedValue('hello')
    const element = document.getByTest
    const btn = document.getElementById('btn');
  //  console.log(document.querySelector('#btn').textContent)
 //    const mError = new Error('Unable to retrieve rows')
 //   btn.click();
  //  expect(pinwheel.loadPinwheel).toHaveBeenCalled()
 //   expect(document.querySelector('#btn').textContent).toBe('Employee Search Button Text')
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