/// Photos for observations now live in the first-class `attachments`
/// table (UX_DECISIONS §8). Readers should watch
/// `attachmentsForEntityProvider(({kind: 'entry', id: entry.id}))`
/// instead of `entry.photos`.
///
/// Writers go through `AttachmentActions.add` after uploading bytes
/// via `PhotoService.uploadOnly`. `EntryActions.createObservation` /
/// `updateText` accept a `photoUrls` parameter and persist each
/// matching attachment row in the right sort_order on save.
library;
