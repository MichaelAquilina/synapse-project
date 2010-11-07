using Gtk;

namespace UI.Widgets
{
  public class WrapLabel: Label
  {
    private float orig_yalign = 0.5f;
    private bool _wrap = false;
    public new bool wrap { 
      get
      {
        return _wrap;
      }
      construct set
      {
        _wrap = value;
        this.max_width_chars = _wrap ? -1 : 10;
        this.set_ellipsize (_wrap ? Pango.EllipsizeMode.NONE : 
                                    Pango.EllipsizeMode.END);
        if (!_wrap) orig_yalign = this.yalign;
        this.yalign = _wrap ? 0.0f : orig_yalign;
        this.queue_resize ();
      }
    }
    public WrapLabel ()
    {
      GLib.Object (xalign: 0.0f, wrap: false);
    }

    construct
    {
    }

    protected override void size_allocate (Gdk.Rectangle allocation)
    {
      var layout = this.get_layout ();
      layout.set_width (allocation.width * Pango.SCALE);

      int lw, lh;
      layout.get_pixel_size (out lw, out lh);

      this.height_request = lh;

      base.size_allocate (allocation);
    }

    protected override void size_request (out Gtk.Requisition req)
    {
      base.size_request (out req);
      if (_wrap) req.width = 1;
    }
  }
}
