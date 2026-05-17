/**
 * Model pricing constants in USD per request (image models) or per second (video models)
 * Based on FAL.ai pricing (2024)
 */

const IMAGE_MODEL_PRICES: Record<string, number> = {
  "openai/gpt-image-2/edit": 0.219,
  "fal-ai/nano-banana-pro/edit": 0.15,
  "fal-ai/flux-2-pro/edit": 0.03,
  "fal-ai/gpt-image-1.5/edit": 0.133,
  "fal-ai/bytedance/seedream/v5/lite/edit": 0.035,
  "fal-ai/nano-banana-2/edit": 0.08,
};

const MOTION_MODEL_PRICES: Record<string, number> = {
  "fal-ai/kling-video/v3/pro/motion-control": 0.168,
  "fal-ai/kling-video/v3/standard/motion-control": 0.126,
};

/**
 * Get price for image generation model
 * @param model Model name
 * @returns Price in USD per request, or null if model not found
 */
export function getImageModelPrice(model: string | undefined): number | null {
  if (!model) return null;
  const price = IMAGE_MODEL_PRICES[model];
  return price !== undefined ? price : null;
}

/**
 * Format price as USD string
 * @param price Price in USD
 * @returns Formatted string like "$0.219"
 */
export function formatPrice(price: number | null | undefined): string | null {
  if (price === null || price === undefined) return null;
  return `$${price.toFixed(3)}`;
}

/**
 * Get motion model price per second
 * @param model Model name
 * @returns Price in USD per second, or null if model not found
 */
export function getMotionModelPrice(model: string | undefined): number | null {
  if (!model) return null;
  const price = MOTION_MODEL_PRICES[model];
  return price !== undefined ? price : null;
}

/**
 * Get all image model prices
 */
export function getAllImageModelPrices(): Record<string, number> {
  return { ...IMAGE_MODEL_PRICES };
}

/**
 * Get all motion model prices
 */
export function getAllMotionModelPrices(): Record<string, number> {
  return { ...MOTION_MODEL_PRICES };
}
