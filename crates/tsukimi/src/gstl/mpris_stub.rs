// No-op replacements for the MPRIS interface on platforms without D-Bus.

use anyhow::Result;

use super::player::MusicPlayer;

impl MusicPlayer {
    pub async fn initialize_mpris(&self) -> Result<()> {
        Ok(())
    }

    pub fn notify_mpris_song_changed(&self, _has_prev: bool, _has_next: bool) {}

    pub fn notify_mpris_playing(&self) {}

    pub fn notify_mpris_paused(&self) {}

    pub fn notify_mpris_stopped(&self) {}

    pub fn notify_mpris_seeked(&self, _position: i64) {}
}
