export interface ModalAdapterArgs {
  requestData: RequestData;
  onSuccess?: Function;
  onExit?: Function;
}

export interface RequestData {
  responseType: string;
  id: string;
  isDefaultOption: boolean;
  providerName: string;
  name: string;
}
