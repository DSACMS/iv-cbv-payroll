import { expect, test, beforeEach } from 'vitest'
import { application } from '@js/controllers/application'

beforeEach(() => {
  // Reset application state before each test
  window.Stimulus = window.Stimulus || {}
})

test('Expect Application to be setup correctly', () => {
  expect(window).toHaveProperty('Stimulus')
  expect(window.Stimulus.debug).toBeFalsy()
})

test('Expect application to be registered', () => {
  expect(application).toBeTruthy()
  expect(typeof application.register).toBe('function')
  expect(application.debug).toBe(false)
})
