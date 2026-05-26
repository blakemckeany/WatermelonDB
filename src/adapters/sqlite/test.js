import fs from 'fs'
import { testSchema } from '../__tests__/helpers'
import commonTests from '../__tests__/commonTests'

import SqliteAdapter from './index'
import DatabaseAdapterCompat from '../compat'

function removeIfExists(file, dbName) {
  if (file && fs.existsSync(dbName)) {
    fs.unlinkSync(dbName)
  }
}

describe('SQLiteAdapter passphrase invariant', () => {
  it('throws when passphrase is missing', () => {
    expect(() => new SqliteAdapter({ schema: testSchema })).toThrow(/passphrase/i)
  })

  it('throws when passphrase is an empty string', () => {
    expect(() => new SqliteAdapter({ schema: testSchema, passphrase: '' })).toThrow(/passphrase/i)
  })

  it('throws when passphrase is not a string', () => {
    expect(
      // $FlowFixMe — intentional bad input
      () => new SqliteAdapter({ schema: testSchema, passphrase: 12345 }),
    ).toThrow(/passphrase/i)
  })
})

describe.each([
  // ['SQLiteAdapterNode', 'Asynchronous', 'File'],
  ['SQLiteAdapterNode', 'Asynchronous', 'Memory'],
])('%s (%s/%s)', (adapterSubclass, fileString) => {
  commonTests().forEach((testCase) => {
    const [name, test] = testCase

    if (name.match(/from file system/) && process.platform === 'win32') {
      // eslint-disable-next-line no-console
      console.error(`FIXME: Broken test on Windows! ${name}`)
      return
    }

    // eslint-disable-next-line jest/valid-title
    it(name, async () => {
      const file = fileString.toLowerCase() === 'file'

      // NOTE: one test uses .tmp/xx path, but we have to create it first
      if (!fs.existsSync('.tmp')) {
        fs.mkdirSync('.tmp')
      }

      const dbName = `${process.cwd()}/test${Math.random()}.db${
        file ? '' : '?mode=memory&cache=shared'
      }`
      const extraAdapterOptions = {
        dbName,
        adapterSubclass,
        passphrase: 'watermelon-jest-test-passphrase',
      }
      const adapter = new SqliteAdapter({
        dbName,
        schema: testSchema,
        passphrase: 'watermelon-jest-test-passphrase',
      })

      try {
        await adapter.initializingPromise
        await test(new DatabaseAdapterCompat(adapter), SqliteAdapter, extraAdapterOptions, 'node')
      } finally {
        removeIfExists(file, dbName)
      }
    })
  })
})
