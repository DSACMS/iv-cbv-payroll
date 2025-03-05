type LinkResult = {
  accountId: string
  platformId: string
  job: string
  params: {
    amount?: { value: number; unit: "%" | "$" }
  }
}

type PinwheelError = { type: string; code: string; message: string; pendingRetry: boolean }

type InitializationParams = {
  linkToken: string
  onLogin?: (result: { accountId: string; platformId: string }) => void
  onSuccess?: (result: LinkResult) => void
  onError?: (error: PinwheelError) => void
  onExit?: (error?: PinwheelError) => void
  onEvent?: (name: string, payload: EventPayload) => void
}

type Pinwheel = {
  open: (params: InitializationParams) => void
  close: () => void
}
