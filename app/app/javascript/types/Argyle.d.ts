type LinkError = {
  userId: string
  errorType: string
  errorMessage: string
  errorDetails: string
}

type ArgyleInitializationParams = {
  userToken: string
  items: string[]
  onAccountConnected?: (payload: ArgyleAccountData) => void
  onTokenExpired?: (updateToken: Function) => void
  onAccountCreated?: (payload: ArgyleAccountData) => void
  onAccountError?: (payload: ArgyleAccountData) => void
  onAccountRemoved?: (payload: ArgyleAccountData) => void
  onClose?: () => void
  onError?: (payload: LinkError) => void
  sandbox?: boolean
}

type Argyle = {
  create: (params: ArgyleInitializationParams) => {
    open: () => void
    close: () => void
  }
}

type ArgyleAccountData = {
  accountId: string
  userId: string
  itemId: string
}

type ArgyeUIEvent = {
  name: string
  properties: {
    deepLink: boolean
    userId: string
    accountId?: string
    itemId?: string
  }
}
