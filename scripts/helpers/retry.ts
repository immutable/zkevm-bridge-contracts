import { providers, utils } from "ethers";

const MAX_ATTEMPT = 20;

export class RetryProvider extends providers.JsonRpcProvider {

  constructor(
    url?: utils.ConnectionInfo | string,
    network?: providers.Networkish
  ) {
    super(url, network);
  }

  public perform(method: string, params: any) {
    let attempts = 0;
    return utils.poll(() => {
      if (attempts != 0) {
        console.log("Retry RPC Request: " + attempts);
      }
      attempts++;
      return super.perform(method, params)
        .then(result => {
            return result;
        }, (error: any) => {
          if (error.statusCode !== 429) {
            return Promise.reject(error);
          } else {
            return Promise.resolve(undefined);
          }
        })
        .catch(error => {
          console.log(error);
          return Promise.resolve(undefined);
        })
    }, {
      retryLimit: MAX_ATTEMPT,
    });
  }
}
