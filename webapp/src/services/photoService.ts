import type { SupabaseClient } from '@supabase/supabase-js';
import { getSupabaseClient } from '../lib/supabase';
import { makePhotoStoragePath, type PhotoRow } from './sessionService';

export interface UploadPhotoInput {
  sessionId: string;
  participantId: string;
  anonymousId?: string | null;
  file: File;
  width?: number | null;
  height?: number | null;
  metadata?: Record<string, unknown>;
  client?: SupabaseClient;
}

export async function uploadPhoto(input: UploadPhotoInput): Promise<PhotoRow> {
  const client = input.client ?? getSupabaseClient();
  const storagePath = makePhotoStoragePath(input.sessionId, input.file);

  const { error: uploadError } = await client.storage
    .from('photos')
    .upload(storagePath, input.file, {
      contentType: input.file.type || 'application/octet-stream',
      upsert: false,
    });

  if (uploadError) throw new Error(uploadError.message);

  const { data: photo, error: insertError } = await client
    .from('photos')
    .insert({
      session_id: input.sessionId,
      uploaded_by: input.participantId,
      anonymous_id: input.anonymousId ?? null,
      storage_path: storagePath,
      file_name: input.file.name,
      mime_type: input.file.type || null,
      width: input.width ?? null,
      height: input.height ?? null,
      size_bytes: input.file.size,
      metadata: input.metadata ?? {},
    })
    .select()
    .single();

  if (insertError || !photo) throw new Error(insertError?.message ?? 'Photo metadata insert failed.');
  return photo as PhotoRow;
}
