import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    globals: false,
    environment: 'node',
    pool: 'forks',
    poolOptions: {
      forks: { singleFork: true }, // all the tests are executed on the same db
    },
  },
})