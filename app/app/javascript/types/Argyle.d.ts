type LinkError = {
  userId: string
  errorType: string
  errorMessage: string
  errorDetails: string
}

type ArgyleInitializationParams = {
  // See: https://docs.argyle.com/link/initialization
  flowId: string
  userToken: string
  items: string[]
  onAccountConnected?: (payload: ArgyleAccountData) => void
  onTokenExpired?: (updateToken: Function) => void
  onAccountCreated?: (payload: ArgyleAccountData) => void
  onAccountError?: (payload: ArgyleAccountData) => void
  onAccountRemoved?: (payload: ArgyleAccountData) => void
  onClose?: () => void
  onError?: (payload: LinkError) => void
  onUIEvent?: (payload: ArgyeUIEvent) => void
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
    errorCode?:
      | "auth_required"
      | "connection_unavailable"
      | "expired_credentials"
      | "invalid_auth"
      | "invalid_credentials"
      | "mfa_cancelled_by_the_user"
    errorMessage?: string
    term?: string
    tab?: string
  }
}
