[CCode (cprefix = "G", lower_case_cprefix = "g_", cheader_filename = "gio/gio.h")]
namespace CancellableFix
{
  public delegate void Callback (GLib.Cancellable instance);
  [CCode (cname = "g_cancellable_connect")]
  public static ulong connect (GLib.Cancellable instance,
                               owned Callback callback);
}

