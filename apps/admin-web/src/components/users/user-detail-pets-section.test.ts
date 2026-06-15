import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const detailPagePath = fileURLToPath(new URL("./user-detail-page.tsx", import.meta.url));
const detailStylesPath = fileURLToPath(new URL("./user-detail-page.module.css", import.meta.url));

describe("user detail pets section", () => {
  it("uses localized copy for the pets workflow instead of hardcoded English text", () => {
    const source = readFileSync(detailPagePath, "utf8");

    expect(source).toContain("function getUserPetsCopy(locale: Locale)");
    expect(source).toContain('title: isRu ? "Питомцы" : "Pets"');
    expect(source).toContain("title={petText.title}");
    expect(source).toContain("description={petText.description}");
    expect(source).not.toContain('AdminCard title="Pets"');
    expect(source).not.toContain(">No pets yet.<");
    expect(source).not.toContain(">Loading photos...<");
    expect(source).not.toContain(">Hide photo<");
    expect(source).not.toContain(">No pet generations.<");
  });

  it("keeps pet, photo, and generation failures retryable", () => {
    const source = readFileSync(detailPagePath, "utf8");

    expect(source).toContain("petsQuery.isError");
    expect(source).toContain("getAdminErrorMessage(petsQuery.error, petText.loadError)");
    expect(source).toContain("void petsQuery.refetch().catch(() => undefined)");
    expect(source).toContain("photosQuery.isError");
    expect(source).toContain("void photosQuery.refetch().catch(() => undefined)");
    expect(source).toContain("generationsQuery.isError");
    expect(source).toContain("void generationsQuery.refetch().catch(() => undefined)");
  });

  it("loads expensive pet details only after the admin expands a pet card", () => {
    const source = readFileSync(detailPagePath, "utf8");
    const styles = readFileSync(detailStylesPath, "utf8");

    expect(source).toContain("const [expandedPetIds, setExpandedPetIds]");
    expect(source).toContain("{isExpanded ? (");
    expect(source).toContain("<AdminPetDetails");
    expect(source).toContain("showDetails");
    expect(source).toContain("hideDetails");
    expect(source).toContain("function requestPetStatusChange(pet: AdminUserPet)");
    expect(source).toContain(
      "if (!canViewUserProfile || petStatusMutation.isPending) {\n      return;\n    }"
    );
    expect(source).toContain("onClick={() => requestPetStatusChange(pet)}");
    expect(source).not.toContain(
      "onClick={() =>\n                        petStatusMutation.mutate({"
    );
    expect(source).toContain("function requestPhotoStatusChange(photo: AdminUserPetPhoto)");
    expect(source).toContain(
      "if (!canManagePets || photoStatusMutation.isPending) {\n      return;\n    }"
    );
    expect(source).toContain("disabled={!canManagePets || photoStatusMutation.isPending}");
    expect(source).toContain("onClick={() => requestPhotoStatusChange(photo)}");
    expect(source).not.toContain(
      "onClick={() =>\n                  photoStatusMutation.mutate({"
    );
    expect(styles).toContain(".petDetailState");
  });

  it("keeps pet and photo status refreshes non-blocking after successful mutations", () => {
    const source = readFileSync(detailPagePath, "utf8");

    expect(source).toContain(
      'await Promise.allSettled([\n        queryClient.invalidateQueries({ queryKey: ["admin", "users", userId, "pets"] }),\n      ]);'
    );
    expect(source).toContain(
      'await Promise.allSettled([\n        queryClient.invalidateQueries({\n          queryKey: ["admin", "users", userId, "pets", pet.id, "photos"],\n        }),\n      ]);'
    );
    expect(source).not.toContain(
      'await queryClient.invalidateQueries({ queryKey: ["admin", "users", userId, "pets"] });'
    );
    expect(source).not.toContain(
      'await queryClient.invalidateQueries({\n        queryKey: ["admin", "users", userId, "pets", pet.id, "photos"],\n      });'
    );
  });
});
