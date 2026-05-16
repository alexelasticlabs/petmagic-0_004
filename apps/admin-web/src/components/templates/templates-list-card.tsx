import { AdminCard, AdminStatusBadge, adminTableStyles } from "@/components/admin/admin-primitives";
import styles from "@/components/templates/templates-admin.module.css";
import { Button } from "@/components/ui/button";
import type { AdminTemplateListItem, TemplateStatus } from "@/lib/api-client";
import type { Dictionary } from "@/lib/i18n";

type TemplatesListCardProps = {
  text: Dictionary;
  sectionTitle: string;
  isVideo: boolean;
  templates: AdminTemplateListItem[];
  busyTemplateId: string | null;
  error: string | null;
  onCreateNew: () => void;
  onOpenTemplate: (templateId: string) => void;
  onChangeStatus: (templateId: string, status: TemplateStatus) => void;
  onDeleteTemplate: (templateId: string) => void;
};

export function TemplatesListCard({
  text,
  sectionTitle,
  isVideo,
  templates,
  busyTemplateId,
  error,
  onCreateNew,
  onOpenTemplate,
  onChangeStatus,
  onDeleteTemplate,
}: TemplatesListCardProps) {
  const statusColors: Record<TemplateStatus, string> = {
    Draft: "#8da1ba",
    Active: "#22c55e",
    Archived: "#f87171",
  };

  return (
    <AdminCard
      title={sectionTitle}
      description={text.templatesHint}
      action={(
        <Button type="button" variant="secondary" className={styles.primaryButton} onClick={onCreateNew}>
          {text.createNewTemplate}
        </Button>
      )}
    >

      {error ? <p className={styles.error}>{error}</p> : null}
      {!templates.length ? <div className={styles.empty}>{text.noTemplates}</div> : null}

      {!!templates.length && (
        <div className={adminTableStyles.tableWrap}>
          <table className={adminTableStyles.table}>
            <thead>
              <tr>
                <th>{text.titleLabel}</th>
                <th>{text.categoryLabel}</th>
                <th>{text.statusLabel}</th>
                {isVideo ? <th>{text.characterOrientationLabel}</th> : null}
                <th>{text.actionsLabel}</th>
              </tr>
            </thead>
            <tbody>
              {templates.map((template) => {
                const isBusy = busyTemplateId === template.templateId;

                return (
                  <tr key={template.templateId}>
                    <td data-label={text.titleLabel}>
                      <div className={styles.titleCell}>
                        <strong>{template.title}</strong>
                        <span className={styles.tagText}>{template.tags.join(", ")}</span>
                      </div>
                    </td>
                    <td data-label={text.categoryLabel}>{template.category}</td>
                    <td data-label={text.statusLabel}>
                      <AdminStatusBadge color={statusColors[template.status]}>{template.status}</AdminStatusBadge>
                    </td>
                    {isVideo ? (
                      <td data-label={text.characterOrientationLabel}>{template.characterOrientation ?? "-"}</td>
                    ) : null}
                    <td data-label={text.actionsLabel} className={styles.actionsCell}>
                      <div className={styles.actions}>
                        <Button type="button" variant="secondary" size="sm" className={styles.primaryButton} disabled={isBusy} onClick={() => onOpenTemplate(template.templateId)}>
                          {text.editTemplate}
                        </Button>
                        {template.status !== "Active" ? (
                          <Button type="button" variant="ghost" size="sm" className={styles.adminButton} disabled={isBusy} onClick={() => onChangeStatus(template.templateId, "Active")}>
                            {text.activate}
                          </Button>
                        ) : null}
                        {template.status !== "Draft" ? (
                          <Button type="button" variant="ghost" size="sm" className={styles.adminButton} disabled={isBusy} onClick={() => onChangeStatus(template.templateId, "Draft")}>
                            {text.moveToDraft}
                          </Button>
                        ) : null}
                        {template.status !== "Archived" ? (
                          <Button type="button" variant="danger" size="sm" className={styles.dangerButton} disabled={isBusy} onClick={() => onChangeStatus(template.templateId, "Archived")}>
                            {text.archive}
                          </Button>
                        ) : null}
                        <Button type="button" variant="danger" size="sm" className={styles.dangerButton} disabled={isBusy} onClick={() => onDeleteTemplate(template.templateId)}>
                          {text.deleteTemplate}
                        </Button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </AdminCard>
  );
}
