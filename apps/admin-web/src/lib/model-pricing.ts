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

export function getImageModelPrice(model: string | undefined): number | null {
  if (!model) {
    return null;
  }

  const price = IMAGE_MODEL_PRICES[model];
  return price !== undefined ? price : null;
}

export function formatPrice(price: number | null | undefined): string | null {
  if (price === null || price === undefined) {
    return null;
  }

  return `$${price.toFixed(3)}`;
}

export function getMotionModelPrice(model: string | undefined): number | null {
  if (!model) {
    return null;
  }

  const price = MOTION_MODEL_PRICES[model];
  return price !== undefined ? price : null;
}
