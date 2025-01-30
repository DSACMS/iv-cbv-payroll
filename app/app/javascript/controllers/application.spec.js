import { expect, test } from 'vitest'
import { application } from './application.js'


test('Expect Application to be setup correctly', () => {
  expect(window).toHaveProperty("Stimulus")
  expect(window.Stimulus.debug).toBeFalsy()
})