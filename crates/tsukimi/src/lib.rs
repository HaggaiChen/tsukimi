use std::{
    env,
    sync::LazyLock,
};

mod app;
mod arg;
mod config;
mod gstl;
mod macros;

#[cfg(target_os = "linux")]
mod mpris_common;
mod ui;
mod utils;

pub mod client;

pub use arg::Args;
use clap::Parser;
pub use config::*;
use gettextrs::*;
use gtk::prelude::*;

pub use ui::Window;

pub use app::TsukimiApplication as Application;

use crate::client::runtime::runtime;

pub static USER_AGENT: LazyLock<String> =
    LazyLock::new(|| format!("{}/{} - {}", CLIENT_ID, version(), env::consts::OS));

pub const APP_ID: &str = "moe.tsuna.tsukimi";
pub const CLIENT_ID: &str = "Tsukimi";
const APP_RESOURCE_PATH: &str = "/moe/tsuna/tsukimi";
const GRESOURCE_FILE: &str = "tsukimi.gresource";

pub fn run() -> gtk::glib::ExitCode {
    #[cfg(target_os = "windows")]
    init_portable_dirs();

    Args::parse().init();

    // Initialize gettext
    unsafe { setlocale(LocaleCategory::LcAll, String::new()) };
    bind_textdomain_codeset(GETTEXT_PACKAGE, "UTF-8").expect("Failed to set textdomain codeset");
    #[cfg(target_os = "linux")]
    bindtextdomain(GETTEXT_PACKAGE, LOCALEDIR).expect("Invalid argument passed to bindtextdomain");
    #[cfg(not(target_os = "linux"))]
    bindtextdomain(GETTEXT_PACKAGE, locale_dir())
        .expect("Invalid argument passed to bindtextdomain");

    textdomain(GETTEXT_PACKAGE).expect("Invalid string passed to textdomain");

    adw::init().expect("Failed to initialize Adwaita");
    mutsumi::init();

    register_gio_resources();

    ui::init();

    gtk::glib::set_application_name(CLIENT_ID);

    let _tokio_guard = runtime().enter();
    Application::new().run_with_args::<&str>(&[])
}

fn register_gio_resources() {
    let path = gresource_path();
    let resources = gtk::gio::Resource::load(&path).expect("Failed to load resources.");
    gtk::gio::resources_register(&resources);
}

#[cfg(target_os = "linux")]
fn gresource_path() -> std::path::PathBuf {
    std::path::Path::new(PKGDATADIR).join(GRESOURCE_FILE)
}

// Portable packages ship the gresource next to the executable; fall back to
// it when the path baked in at build time does not exist (e.g. a zip package
// moved off the build machine).
#[cfg(not(target_os = "linux"))]
fn gresource_path() -> std::path::PathBuf {
    let baked = std::path::Path::new(PKGDATADIR).join(GRESOURCE_FILE);
    if baked.exists() {
        return baked;
    }
    exe_dir().join("share").join("tsukimi").join(GRESOURCE_FILE)
}

#[cfg(not(target_os = "linux"))]
fn exe_dir() -> std::path::PathBuf {
    std::env::current_exe()
        .ok()
        .and_then(|p| p.parent().map(|p| p.to_path_buf()))
        .unwrap_or_default()
}

// Redirect GLib's cache/config dirs (and the GSettings storage backend) into
// the directory the exe lives in, so the zip package is fully portable and
// never writes to %LOCALAPPDATA% or the registry.
#[cfg(target_os = "windows")]
fn init_portable_dirs() {
    let root = exe_dir();
    unsafe {
        if env::var_os("XDG_CACHE_HOME").is_none() {
            env::set_var("XDG_CACHE_HOME", root.join("cache"));
        }
        if env::var_os("XDG_CONFIG_HOME").is_none() {
            env::set_var("XDG_CONFIG_HOME", root.join("config"));
        }
        if env::var_os("GSETTINGS_BACKEND").is_none() {
            env::set_var("GSETTINGS_BACKEND", "keyfile");
        }
    }
}

#[cfg(not(target_os = "linux"))]
fn locale_dir() -> String {
    let baked = std::path::Path::new(LOCALEDIR);
    if baked.exists() {
        return LOCALEDIR.to_owned();
    }
    exe_dir()
        .join("share")
        .join("locale")
        .to_string_lossy()
        .into_owned()
}
