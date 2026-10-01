export type Config = { [key: string]: unknown };

export function mergeConfig(base: Config, override: Config): Config {
  return { ...base, ...override };
}
