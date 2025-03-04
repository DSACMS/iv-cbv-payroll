declare module "load-script" {
  type loadScriptCallback = (error : object, script: object) => void;
  function loadScript(url: string, callback: loadScriptCallback): void; 
  export = loadScript;
}
