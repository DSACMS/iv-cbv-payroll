type LinkResult = {
  accountId: string;
  platformId: string;
  job: string;
  params: {
    amount?: { value: number, unit: '%' | '$' }
  }
}

type ArgyleError = { type: string; code: string; message: string, pendingRetry: boolean }

type ArgyleInitializationParams = {
  userToken: string;
  items: string[];
  onAccountConnected?: (result: { accountId: string, platformId: string }) => void;
  sandbox?: boolean;
};

type Argyle = {
  create: (params : ArgyleInitializationParams) => {
    open: () => void;
    close: () => void;
  };
}
