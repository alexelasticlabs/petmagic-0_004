import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const detailPagePath = fileURLToPath(new URL("./user-detail-page.tsx", import.meta.url));
const detailContentPath = fileURLToPath(new URL("./user-detail-page.content.ts", import.meta.url));
const detailStylesPath = fileURLToPath(new URL("./user-detail-page.module.css", import.meta.url));

describe("user detail pets section", () => {
  it("uses localized copy for the pets workflow instead of hardcoded English text", () => {
    const source = readFileSync(detailPagePath, "utf8");
    const contentSource = readFileSync(detailContentPath, "utf8");

    expect(source).toContain("getUserDetailPetText");
    expect(source).toContain("type UserDetailPetText");
    expect(source).toContain('from "@/components/users/user-detail-page.content";');
    expect(source).toContain(
      "const petText = useMemo(() => getUserDetailPetText(locale), [locale]);"
    );
    expect(source).not.toContain("function getUserPetsCopy(locale: Locale)");
    expect(source).not.toContain('const isRu = locale === "ru";');
    expect(contentSource).toContain('title: "Питомцы"');
    expect(contentSource).toContain('activeStatus: "Активен"');
    expect(contentSource).toContain('hiddenStatus: "Скрыт"');
    expect(contentSource).toContain('hidePetLabel: "Скрыть питомца"');
    expect(contentSource).toContain('restorePhotoLabel: "Восстановить фото питомца"');
    expect(contentSource).toContain('thumbnailReady: "миниатюра готова"');
    expect(contentSource).toContain('originalOnly: "только оригинал"');
    expect(source).toContain("function formatPetStatus(");
    expect(source).toContain('if (status === "active")');
    expect(source).toContain("return text.activeStatus;");
    expect(source).toContain('if (status === "hidden")');
    expect(source).toContain("return text.hiddenStatus;");
    expect(source).toContain("title={petText.title}");
    expect(source).toContain("description={petText.description}");
    expect(source).toContain("formatPetStatus(pet.status, petText)");
    expect(source).toContain("formatPetStatus(photo.status, text)");
    expect(source).not.toContain('AdminCard title="Pets"');
    expect(source).not.toContain(">No pets yet.<");
    expect(source).not.toContain(">Loading photos...<");
    expect(source).not.toContain(">Hide photo<");
    expect(source).not.toContain(">No pet generations.<");
    expect(contentSource).not.toContain("thumbnail готов");
    expect(contentSource).not.toContain("только original");
    expect(source).not.toContain("{sanitizeSensitiveText(pet.status, 32)}");
    expect(source).not.toContain("{sanitizeSensitiveText(photo.status, 32)}");
  });

  it("keeps pet, photo, and generation failures retryable", () => {
    const source = readFileSync(detailPagePath, "utf8");

    expect(source).toContain("petsQuery.isError");
    expect(source).toContain("getAdminErrorMessage(petsQuery.error, petText.loadError)");
    expect(source).toContain("function requestPetsRetry()");
    expect(source).toContain(
      "if (!canViewUserProfile || petsQuery.isFetching) {\n      return;\n    }"
    );
    expect(source).toContain("void petsQuery.refetch().catch(() => undefined)");
    expect(source).toContain("onClick={requestPetsRetry}");
    expect(source).toContain("disabled={!canViewUserProfile || petsQuery.isFetching}");
    expect(source).toContain("photosQuery.isError");
    expect(source).toContain("function requestPhotosRetry()");
    expect(source).toContain(
      "if (!canManagePets || photosQuery.isFetching) {\n      return;\n    }"
    );
    expect(source).toContain("void photosQuery.refetch().catch(() => undefined)");
    expect(source).toContain("onClick={requestPhotosRetry}");
    expect(source).toContain("disabled={!canManagePets || photosQuery.isFetching}");
    expect(source).toContain("generationsQuery.isError");
    expect(source).toContain("function requestGenerationsRetry()");
    expect(source).toContain(
      "if (!canManagePets || generationsQuery.isFetching) {\n      return;\n    }"
    );
    expect(source).toContain("void generationsQuery.refetch().catch(() => undefined)");
    expect(source).toContain("onClick={requestGenerationsRetry}");
    expect(source).toContain("disabled={!canManagePets || generationsQuery.isFetching}");
    expect(source).not.toContain("onClick={() => void petsQuery.refetch().catch(() => undefined)}");
    expect(source).not.toContain("disabled={photosQuery.isFetching}");
    expect(source).not.toContain("disabled={generationsQuery.isFetching}");
  });

  it("loads expensive pet details only after the admin expands a pet card", () => {
    const source = readFileSync(detailPagePath, "utf8");
    const styles = readFileSync(detailStylesPath, "utf8");

    expect(source).toContain("const [expandedPetIds, setExpandedPetIds]");
    expect(source).toContain("{isExpanded ? (");
    expect(source).toContain("<AdminPetDetails");
    expect(source).toContain("showDetails");
    expect(source).toContain("hideDetails");
    expect(source).toContain("enabled: canManagePets");
    expect(source).toContain("function requestPetStatusChange(pet: AdminUserPet)");
    expect(source).toContain("const [petActionError, setPetActionError]");
    expect(source).toContain('clientLogger.warn("users.pet_status_update_failed", {');
    expect(source).toContain("petId: sanitizeSensitiveText(variables.petId, 80)");
    expect(source).toContain("status: variables.status");
    expect(source).toContain("function getUserPetActionErrorDetails(error: unknown)");
    expect(source).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(source).toContain(
      "setPetActionError(getAdminErrorMessage(error, petText.statusUpdateError));"
    );
    expect(source).toContain(
      '{petActionError ? <AdminStateCard tone="warning" title={petActionError} /> : null}'
    );
    expect(source).toContain(
      "const isPetActionLocked = petStatusMutation.isPending || petsQuery.isFetching;"
    );
    expect(source).toContain(
      "if (!canViewUserProfile || isPetActionLocked) {\n      return;\n    }"
    );
    expect(source).toContain("disabled={!canViewUserProfile || isPetActionLocked}");
    expect(source).toContain(
      'aria-label={`${\n                        pet.status === "active" ? petText.hidePetLabel : petText.restorePetLabel'
    );
    expect(source).toContain("onClick={() => requestPetStatusChange(pet)}");
    expect(source).not.toContain(
      "onClick={() =>\n                        petStatusMutation.mutate({"
    );
    expect(source).toContain("function requestPhotoStatusChange(photo: AdminUserPetPhoto)");
    expect(source).toContain("const [photoActionError, setPhotoActionError]");
    expect(source).toContain('clientLogger.warn("users.pet_photo_status_update_failed", {');
    expect(source).toContain("photoId: sanitizeSensitiveText(variables.photoId, 80)");
    expect(source).toContain("...getUserPetActionErrorDetails(error)");
    expect(source).toContain(
      "setPhotoActionError(getAdminErrorMessage(error, text.photoStatusUpdateError));"
    );
    expect(source).toContain(
      '{photoActionError ? <AdminStateCard tone="warning" title={photoActionError} /> : null}'
    );
    expect(source).toContain(
      "const isPhotoActionLocked = photoStatusMutation.isPending || photosQuery.isFetching;"
    );
    expect(source).toContain("if (!canManagePets || isPhotoActionLocked) {\n      return;\n    }");
    expect(source).toContain("disabled={!canManagePets || isPhotoActionLocked}");
    expect(source).toContain(
      'aria-label={`${\n                  photo.status === "active" ? text.hidePhotoLabel : text.restorePhotoLabel'
    );
    expect(source).toContain("aria-busy={");
    expect(source).toContain("onClick={() => requestPhotoStatusChange(photo)}");
    expect(source).not.toContain("onClick={() =>\n                  photoStatusMutation.mutate({");
    expect(source).not.toContain('clientLogger.warn("users.pet_status_update_failed", { error');
    expect(source).not.toContain(
      'clientLogger.warn("users.pet_photo_status_update_failed", { error'
    );
    expect(styles).toContain(".petDetailState");
  });

  it("clears stale expanded pet details after the pet list refreshes", () => {
    const source = readFileSync(detailPagePath, "utf8");

    expect(source).toContain(
      "const visiblePetIds = useMemo(\n    () => new Set((petsQuery.data ?? []).map((pet) => pet.id)),"
    );
    expect(source).toContain("if (!petsQuery.data || expandedPetIds.size === 0) {");
    expect(source).toContain("const hasStaleExpandedPet = Array.from(expandedPetIds).some(");
    expect(source).toContain("(petId) => !visiblePetIds.has(petId)");
    expect(source).toContain("queueMicrotask(() => {");
    expect(source).toContain("let isActive = true;");
    expect(source).toContain("if (!isActive) {\n        return;\n      }");
    expect(source).toContain(
      "const next = new Set([...current].filter((petId) => visiblePetIds.has(petId)));"
    );
    expect(source).toContain("return next.size === current.size ? current : next;");
    expect(source).toContain("return () => {\n      isActive = false;\n    };");
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

  it("keeps long pet detail labels and photo metadata from overflowing narrow cards", () => {
    const styles = readFileSync(detailStylesPath, "utf8");

    expect(styles).toContain(".timelineHeader,\n.dataHeader {\n  min-width: 0;");
    expect(styles).toContain(".timelineHeader strong,\n.dataHeader strong {\n  min-width: 0;");
    expect(styles).toContain("overflow-wrap: anywhere;");
    expect(styles).toContain(".dataHeader span {\n  min-width: 0;");
    expect(styles).toContain(".petPhoto {\n  min-width: 0;");
    expect(styles).toContain(".petPhoto span {\n  min-width: 0;\n  overflow-wrap: anywhere;");
    expect(styles).toContain("@media (max-width: 640px)");
    expect(styles).toContain(".petMediaGrid {\n    grid-template-columns: minmax(0, 1fr);");
  });
});
