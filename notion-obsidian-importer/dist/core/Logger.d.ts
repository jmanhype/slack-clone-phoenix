export declare class Logger {
    private logger;
    private static instance;
    private constructor();
    static getInstance(): Logger;
    info(message: string, meta?: any): void;
    warn(message: string, meta?: any): void;
    error(message: string, error?: Error | any): void;
    debug(message: string, meta?: any): void;
    success(message: string): void;
    progress(current: number, total: number, message: string): void;
}
declare const _default: Logger;
export default _default;
//# sourceMappingURL=Logger.d.ts.map