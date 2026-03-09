declare global {
    interface Window {
        /** Increments or decrements the counter by `direction` and returns the new value. */
        count(direction: number): Promise<number>;
        /** Resets the counter to zero and returns `0`. */
        reset(): Promise<number>;
    }
}

export { };
