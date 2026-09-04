import { expect, type Locator, type Page } from "@playwright/test";

export type LayoutBox = {
  x: number;
  y: number;
  width: number;
  height: number;
};

type LayoutViewport = {
  width: number;
  height: number;
};

function right(box: LayoutBox) {
  return box.x + box.width;
}

function bottom(box: LayoutBox) {
  return box.y + box.height;
}

export async function expectNonZeroBoundingBox(
  locator: Locator,
  label: string
): Promise<LayoutBox> {
  await expect(locator, `${label} should be visible`).toBeVisible();
  const box = await locator.boundingBox();

  expect(box, `${label} should have a bounding box`).not.toBeNull();
  expect(box?.width ?? 0, `${label} width`).toBeGreaterThan(0);
  expect(box?.height ?? 0, `${label} height`).toBeGreaterThan(0);

  return box as LayoutBox;
}

export async function expectNoHorizontalDocumentOverflow(page: Page, tolerance = 1) {
  const dimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));

  expect(dimensions.scrollWidth, "document horizontal overflow").toBeLessThanOrEqual(
    dimensions.clientWidth + tolerance
  );
}

export async function expectNoHorizontalElementOverflow(
  locator: Locator,
  label: string,
  tolerance = 1
) {
  const dimensions = await locator.evaluate((element) => ({
    clientWidth: element.clientWidth,
    scrollWidth: element.scrollWidth,
  }));

  expect(dimensions.scrollWidth, `${label} horizontal overflow`).toBeLessThanOrEqual(
    dimensions.clientWidth + tolerance
  );
}

export function expectBoxInsideViewportHorizontally(
  box: LayoutBox,
  viewport: LayoutViewport,
  label: string,
  tolerance = 1
) {
  expect(box.x, `${label} left edge`).toBeGreaterThanOrEqual(-tolerance);
  expect(right(box), `${label} right edge`).toBeLessThanOrEqual(viewport.width + tolerance);
}

export function expectBoxContains(
  container: LayoutBox,
  child: LayoutBox,
  label: string,
  tolerance = 1
) {
  expect(child.x, `${label} left edge`).toBeGreaterThanOrEqual(container.x - tolerance);
  expect(child.y, `${label} top edge`).toBeGreaterThanOrEqual(container.y - tolerance);
  expect(right(child), `${label} right edge`).toBeLessThanOrEqual(right(container) + tolerance);
  expect(bottom(child), `${label} bottom edge`).toBeLessThanOrEqual(bottom(container) + tolerance);
}

export function expectBoxesNotToIntersect(
  first: LayoutBox,
  second: LayoutBox,
  label: string,
  tolerance = 1
) {
  const overlapWidth = Math.min(right(first), right(second)) - Math.max(first.x, second.x);
  const overlapHeight = Math.min(bottom(first), bottom(second)) - Math.max(first.y, second.y);

  expect(
    overlapWidth <= tolerance || overlapHeight <= tolerance,
    `${label} should not intersect (overlap ${overlapWidth.toFixed(1)}x${overlapHeight.toFixed(1)})`
  ).toBe(true);
}

export async function expectVisibleColumnCount(
  items: Locator,
  expectedColumns: number,
  rowTolerance = 2
) {
  const boxes = await items.evaluateAll((elements) =>
    elements
      .map((element) => {
        const rect = element.getBoundingClientRect();
        return { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
      })
      .filter((box) => box.width > 0 && box.height > 0)
  );

  expect(boxes.length, "visible layout items").toBeGreaterThan(0);
  const firstRowTop = Math.min(...boxes.map((box) => box.y));
  const firstRow = boxes
    .filter((box) => Math.abs(box.y - firstRowTop) <= rowTolerance)
    .sort((left, rightBox) => left.x - rightBox.x);

  expect(firstRow, "visible desktop columns").toHaveLength(expectedColumns);
  for (let index = 1; index < firstRow.length; index += 1) {
    expect(firstRow[index].x, `column ${index + 1} order`).toBeGreaterThan(
      firstRow[index - 1].x + firstRow[index - 1].width - rowTolerance
    );
  }
}
