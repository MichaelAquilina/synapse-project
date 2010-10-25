/*
 * Copyright (C) 2010 Michal Hruby <michal.mhr@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA.
 *
 * Authored by Alberto Aldegheri <albyrock87+dev@gmail.com>
 *             Michal Hruby <michal.mhr@gmail.com>
 *
 */

using Gtk;
using Cairo;
using Gee;

namespace Sezen
{
  public class SezenWindow: Window
  {
    /* CONSTANTS */
    private const int PADDING = 10;
    private const int BORDER_RADIUS = 10;
    private const int ICON_SIZE = 172;
    private const int ACTION_ICON_SIZE = 64;
    private const int UI_WIDTH = 550 + PADDING * 2;
    private const int UI_HEIGHT = ICON_SIZE + PADDING * 2;
    private const int UI_LIST_WIDTH = 400;
    private const int UI_LIST_HEIGHT = (35 + 4) * 6 + 2;
    private const int LIST_BORDER_RADIUS = 3;
    private const int TOP_SPACING = UI_HEIGHT * 4 / 10;
    
    private string[] categories = {"All", "Applications", "Actions", "Audio", "Video", "Documents", "Images", "Internet"};
    private QueryFlags[] categories_query = {QueryFlags.ALL, QueryFlags.APPLICATIONS, QueryFlags.ACTIONS, QueryFlags.AUDIO, QueryFlags.VIDEO,
                                             QueryFlags.DOCUMENTS, QueryFlags.IMAGES, QueryFlags.INTERNET};
    
    /* STATUS */
    private bool list_visible = true;

    public SezenWindow ()
    {
      this.set_position (WindowPosition.CENTER);
      this.expose_event.connect (on_expose);
      this.on_composited_changed (this);
      this.composited_changed.connect (on_composited_changed);
      this.set_size_request (UI_WIDTH, UI_HEIGHT+UI_LIST_HEIGHT);
      set_decorated (false);
      set_resizable (false);
      this.build_ui ();
    }
    
    private void rounded_rect (Cairo.Context ctx, double x, double y, double w, double h, double r)
    {
      double y2 = y+h, x2 = x+w;
      ctx.move_to (x, y2 - r);
      ctx.arc (x+r, y+r, r, Math.PI, Math.PI * 1.5);
      ctx.arc (x2-r, y+r, r, Math.PI * 1.5, Math.PI * 2.0);
      ctx.arc (x2-r, y2-r, r, 0, Math.PI * 0.5);
      ctx.arc (x+r, y2-r, r, Math.PI * 0.5, Math.PI);
    }
    
    private void get_shape (Cairo.Context ctx)
    {
      ctx.set_source_rgba (0,0,0,1);
      get_shape_main (ctx);
      get_shape_list (ctx);
    }
    
    private void get_shape_main (Cairo.Context ctx)
    {
      if (this.is_composited ())
      {
        rounded_rect (ctx, 0, TOP_SPACING, UI_WIDTH, UI_HEIGHT - TOP_SPACING, BORDER_RADIUS);
        ctx.fill ();
        ctx.rectangle (PADDING, PADDING, ICON_SIZE, ICON_SIZE);
        ctx.fill ();
      }
      else
        rounded_rect (ctx, 0, 0, UI_WIDTH, UI_HEIGHT, BORDER_RADIUS);
      ctx.fill ();
    }
    
    private void get_shape_list (Cairo.Context ctx)
    {
      if (list_visible)
      {
        rounded_rect (ctx, (UI_WIDTH - UI_LIST_WIDTH) / 2,
                            UI_HEIGHT,
                            UI_LIST_WIDTH,
                            UI_LIST_HEIGHT,
                            LIST_BORDER_RADIUS);
        ctx.fill ();
      }
    }

    private void on_composited_changed (Widget w)
    {
      Gdk.Colormap? cm = w.get_screen ().get_rgba_colormap();
      debug ("Setting colormap rgba %s", cm==null?"No":"si");
      if (cm == null)
        cm = w.get_screen ().get_rgb_colormap();
      this.set_colormap (cm);
      set_mask ();
    }
    
    private void color_to_rgb (Gdk.Color col, double *r, double *g, double *b)
    {
      *r = col.red / (double)65535;
      *g = col.green / (double)65535;
      *b = col.blue / (double)65535;
    }
    
    private void set_mask ()
    {
      var bitmap = new Gdk.Pixmap (null, UI_WIDTH, UI_HEIGHT+UI_LIST_HEIGHT, 1);
      var ctx = Gdk.cairo_create (bitmap);
      ctx.set_operator (Cairo.Operator.CLEAR);
      ctx.paint ();
      ctx.set_operator (Cairo.Operator.OVER);
      get_shape (ctx);
      if (this.is_composited())
      {
        this.input_shape_combine_mask (null, 0, 0);
        this.input_shape_combine_mask ((Gdk.Bitmap*)bitmap, 0, 0);
      }
      else
      {
        this.shape_combine_mask (null, 0, 0);
        this.shape_combine_mask ((Gdk.Bitmap*)bitmap, 0, 0);
      }
    }
    
    private bool on_expose (Widget w, Gdk.EventExpose event) {
        var ctx = Gdk.cairo_create (w.window);
        /* Clear Stage */
        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();
        ctx.set_operator (Cairo.Operator.OVER);

        /* Prepare bg's colors using GtkStyle */
        Gtk.Style style = w.get_style();
        double r = 0.0, g = 0.0, b = 0.0;
        Pattern pat = new Pattern.linear(0, TOP_SPACING, 0, UI_HEIGHT);
        color_to_rgb (style.bg[Gtk.StateType.NORMAL], &r, &g, &b);
        pat.add_color_stop_rgba (0, double.min(r + 0.15, 1),
                                    double.min(g + 0.15, 1),
                                    double.min(b + 0.15, 1),
                                    0.95);
        pat.add_color_stop_rgba (1, double.max(r - 0.15, 0),
                                    double.max(g - 0.15, 0),
                                    double.max(b - 0.15, 0),
                                    0.95);
        /* Prepare and draw top bg's rect */
        int PAD = 1;
        rounded_rect (ctx, PAD, TOP_SPACING + PAD, UI_WIDTH - PAD * 2, UI_HEIGHT - TOP_SPACING - PAD * 2, BORDER_RADIUS);
        ctx.set_source (pat);
        ctx.fill ();
        /* Add border */
        rounded_rect (ctx, PAD, TOP_SPACING + PAD, UI_WIDTH - PAD * 2, UI_HEIGHT - TOP_SPACING - PAD * 2, BORDER_RADIUS);
        ctx.set_line_width (2);
        ctx.set_source_rgba (1-r, 1-g, 1-b, 0.8);
        ctx.stroke ();

        /* Propagate Expose */               
        Container c = (w is Container) ? (Container) w : null;
        if (c != null)
          c.propagate_expose (this.get_child(), event);
        
        return true;
    }
    
    /* UI shared components */
    private Label cat_label;
    private Image main_image;
    private Label main_label;
    private Label main_label_description;
    private Image action_image;
    private Label action_label;
    private SezenTypeSelector sts;
    private ResultBox result_box;
    private HBox list_hbox;
    private HBox top_hbox;

    private void build_ui ()
    {
      /* Constructing Main Areas*/
      
      /* main_vbox: VBox, to separate Top Area from List Area */
      var main_vbox = new VBox (false, 0);
      main_vbox.set_size_request (UI_WIDTH, UI_HEIGHT+UI_LIST_HEIGHT);
      /* top_hbox: HBox, to separate Top Area contents */
      top_hbox = new HBox (false, 0);
      top_hbox.border_width = PADDING;
      top_hbox.set_size_request (UI_WIDTH, UI_HEIGHT);
      /* list_hbox: HBox, to separate List Area contents*/
      list_hbox = new HBox (false, 0);
      list_hbox.set_size_request (UI_LIST_WIDTH, UI_LIST_HEIGHT);
      
      this.add (main_vbox);
      main_vbox.pack_start (top_hbox, false);
      main_vbox.pack_start (list_hbox);
      
      /* Constructing Top Area */
      
      /* Match Icon */
      main_image = new Image ();
      main_image.set_pixel_size (ICON_SIZE);
      main_image.set_from_icon_name ("search", IconSize.DIALOG);
      top_hbox.pack_start (main_image, false);
      
      /* VBox to push down the right area */
      var top_right_vbox = new VBox (false, 0);
      top_hbox.pack_start (top_right_vbox);
      /* Spacer */
      var spacer = new Label("");
      spacer.set_size_request (10, TOP_SPACING - PADDING + 10);
      /* STS */
      sts = new SezenTypeSelector(this.categories);
      /* HBox for the right area */
      var right_hbox = new HBox (false, 0);
      top_right_vbox.pack_start (spacer, false);
      top_right_vbox.pack_start (sts, false);
      top_right_vbox.pack_start (right_hbox);
      
      /* Constructing Top-Right Area */
      var labels_vbox = new VBox (false, 0);
      right_hbox.pack_start (labels_vbox);
      
      /* Match Title and Description */
      main_label = new Label ("");
      main_label.set_alignment (0, 0);
      main_label.set_markup (markup_string_with_search (" ", " "));
      main_label.set_ellipsize (Pango.EllipsizeMode.END);
      //--
      main_label_description = new Label ("");
      main_label_description.set_markup (get_description_markup ("Type to search..."));
      main_label_description.set_alignment (0, 0);
      main_label_description.set_ellipsize (Pango.EllipsizeMode.END); 
      main_label_description.set_line_wrap (true);
      //--
      labels_vbox.pack_end (main_label_description, false);
      labels_vbox.pack_end (main_label, false);
      
      /* Action Area */
      action_image = new Image ();
      action_image.set_pixel_size (ACTION_ICON_SIZE);
      action_image.set_size_request (ACTION_ICON_SIZE, ACTION_ICON_SIZE);
      action_image.set_from_icon_name ("system-run", IconSize.DIALOG);
      right_hbox.pack_start (action_image, false);
      
      /* ResultBox */
      result_box = new ResultBox(UI_LIST_WIDTH);
      var spacerleft = new Label("");
      var spacerright = new Label("");
      spacerright.set_size_request ((UI_WIDTH-UI_LIST_WIDTH) / 2, 10);
      spacerleft.set_size_request ((UI_WIDTH-UI_LIST_WIDTH) / 2, 10);
      list_hbox.pack_start (spacerleft,false);
      list_hbox.pack_start (result_box);
      list_hbox.pack_start (spacerright,false);
      list_hbox.name = "list_hbox";

      this.show_all();
    }
    
    /* EVENTS HANDLING HERE */
    protected override bool key_press_event (Gdk.EventKey event)
    {
      if (im_context.filter_keypress (event)) return true;

      uint key = event.keyval;
      switch (key)
      {
        case Gdk.KeySyms.Return:
        case Gdk.KeySyms.KP_Enter:
        case Gdk.KeySyms.ISO_Enter:
          debug ("enter pressed");
          if (current_match != null)
          {
            current_match.execute ();
            hide ();
            search_reset ();
          }
          break;
        case Gdk.KeySyms.Delete:
        case Gdk.KeySyms.BackSpace:
          search_delete_char ();
          break;
        case Gdk.KeySyms.Escape:
          debug ("escape");
          if (search_string != "")
          {
            search_reset ();
          }
          else
          {
            hide ();
          }
          break;
        case Gdk.KeySyms.Left:
          sts.select_prev ();
          this.search_string = search_string;
          break;
        case Gdk.KeySyms.Right:
          sts.select_next ();
          this.search_string = search_string;
          break;
        case Gdk.KeySyms.Up:
          int i = result_box.move_selection (-1);
          if (i < 0)
            focus_match (null);
          else
            focus_match (results[i]);
          set_list_visible (true);
          break;
        case Gdk.KeySyms.Down:
          int i = result_box.move_selection (1);
          if (i < 0)
            focus_match (null);
          else
            focus_match (results[i]);
          set_list_visible (true);
          break;
        default:
          debug ("im_context didn't filter...");
          break;
      }

      return true;
    }
    private void set_list_visible (bool b)
    {
      if (b==this.list_visible)
        return;
      this.list_visible = b;
      debug ("Set list %s visible", b?"yes": "no");
      if (b)
        list_hbox.show();
      else
        list_hbox.hide();
    }
    
    private void quit ()
    {
      Gtk.main_quit ();
    }

    /* SEZEN STUFFS HERE */
    private IMContext im_context;
    private DataSink data_sink;
    construct
    {
      data_sink = new DataSink();

      set_decorated (false);
      set_resizable (false);

      im_context = new IMMulticontext ();
      im_context.set_use_preedit (false);
      im_context.commit.connect (this.search_add_char);
      im_context.focus_in ();

      this.notify["search-string"].connect (() =>
      {
        bool search_empty = search_string == null || search_string == "";

        data_sink.cancel_search ();

        if (!search_empty)
        {
          data_sink.search (this.search_string, categories_query[sts.get_selected()],
                            this.search_ready);
        }
        else
        {
          result_box.update_matches (null);
          set_list_visible (false);
          main_image.set_from_icon_name ("search", IconSize.DIALOG);
          main_label.set_markup (markup_string_with_search (" "," "));
          main_label_description.set_markup (get_description_markup ("Type to search..."));
        }
      });
    }
    Gee.List<Match> results;
    private void search_ready (GLib.Object? obj, AsyncResult res)
    {
      try
      {
        results = data_sink.search.end (res);
        if (results.size > 0)
        {
          focus_match (results[0]);
          result_box.update_matches (results);
          /*
          foreach (var match in results)
          {
            debug ("got match: %s", match.title);
          }
          /**/
        }
        else
        {
          result_box.update_matches (null);
          set_list_visible (false);
          focus_match (null);
          main_image.set_from_icon_name ("unknown", IconSize.DIALOG);
        }
      }
      catch (SearchError err)
      {
        // most likely cancelled
      }
    }

    public string search_string { get; private set; default = ""; }

    private void search_add_char (string chr)
    {
      search_string += chr;
    }
    
    private void search_delete_char ()
    {
      long len = search_string.length;
      if (len > 0)
      {
        search_string = search_string.substring (0, len - 1);
      }
      else
      {
        search_string = "";
      }
    }

    private void search_reset ()
    {
      search_string = "";
      sts.set_selected (0);
    }
    
    private Match? current_match = null;

    public void focus_match (Match? match)
    {
      current_match = match;
      if (match != null)
      {
        try
        {
          GLib.Icon icon = GLib.Icon.new_for_string (match.has_thumbnail ?
            match.thumbnail_path : match.icon_name);
          main_image.set_from_gicon (icon, IconSize.DIALOG);
        }
        catch (Error err)
        {
          main_image.set_from_icon_name ("missing-image", IconSize.DIALOG);
        }
        main_label.set_markup (markup_string_with_search (match.title, search_string));
        main_label_description.set_markup (get_description_markup (match.description));
      }
      else
      {
        main_label.set_markup (markup_string_with_search ("", search_string));
        main_label_description.set_markup (get_description_markup ("Match not found."));
      }
    }

    /* UTILITY HERE */
    private long strpos (string s, string find)
    {
      string? s2 = s.str(find);
      if (s2 == null)
        return -1;
      else
        return s.length - s2.length;
    }
    
    private string markup_string_with_search (string text, string pattern)
    {
      if (pattern == "")
      {
        return Markup.printf_escaped ("<span size=\"xx-large\"><b><u>%s</u></b></span>",text);
      }
      // if no text found, use pattern
      if (text == "")
      {
        return Markup.printf_escaped ("<span size=\"medium\">%s</span>\n<span size=\"xx-large\"><b><u> </u></b></span>",pattern);
      }
      string t = text.up();
      string p = pattern.up();
      
      // try to find the pattern in the text
      long pos = strpos (t, p);
      if ( pos >= 0)
      {
        return Markup.printf_escaped("<span size=\"xx-large\">%s<u><b>%s</b></u>%s</span>",
                                     text.substring(0,pos),
                                     text.substring(pos, p.length),
                                     text.substring(pos+p.length));
      }
      // not found => search for each char
      string markup = "";
      int j = 0;
      int i = 0;
      for (; i < text.length && j < pattern.length; ++i)
      {
        if (t[i]==p[j])
        {
          markup += Markup.printf_escaped("<u><b>%s</b></u>", text.substring(i,1));
          ++j;
        }
        else
        {
          markup += text.substring(i,1);
        }
      }
      if (j < pattern.length)
      {
        markup = "<span size=\"medium\">"+pattern+"</span>\n<span size=\"xx-large\">"+text+"</span>";
      }
      else
      {
        markup += text.substring(i);
        markup = "<span size=\"xx-large\">"+markup+"</span>";
      }

      return markup;
    }
    
    private string get_description_markup (string s)
    {
      return "<span size=\"medium\"><i>" + s + "</i></span>";
    }
    
    public void show_sezen ()
    {
      this.show_all ();
      set_list_visible (false);
    }
    
    public static int main (string[] argv)
    {
      Gtk.init (ref argv);
      var window = new SezenWindow ();
      window.show_sezen();

      var registry = GtkHotkey.Registry.get_default ();
      GtkHotkey.Info hotkey;
      try
      {
        if (registry.has_hotkey ("sezen2", "activate"))
        {
          hotkey = registry.get_hotkey ("sezen2", "activate");
        }
        else
        {
          hotkey = new GtkHotkey.Info ("sezen2", "activate",
                                       "<Control>space", null);
          registry.store_hotkey (hotkey);
        }
        debug ("Binding activation to %s", hotkey.signature);
        hotkey.bind ();
        hotkey.activated.connect ((event_time) =>
        {
          window.show ();
          window.present_with_time (event_time);
        });
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }

      Gtk.main ();
      return 0;
    }
  }
  
  /* Support Classes */
  public class SezenTypeSelector: Label
  {
    private string[] types;
    private int[] lens;
    private int selected = 0;

    public SezenTypeSelector (string[] types_array)
    {
      this.types = types_array;
      this.lens.resize (types.length);
      this.set_markup ("");
      this.set_alignment (0, 0);
      this.set_ellipsize (Pango.EllipsizeMode.END);
      this.set_selected (0);
    }
    
    public void select_next ()
    {
      set_selected (selected + 1);
    }
    
    public void select_prev ()
    {
      set_selected (selected - 1);
    }
    
    public int get_selected ()
    {
      return selected;
    }
    
    public void set_selected (int sel)
    {
      int i = 0, j = 0;
      if (sel < 0)
        sel = types.length - 1;
      else if (sel >= types.length)
        sel = 0;

      string s = Markup.printf_escaped ("<span size=\"large\">Search Type: &gt; <b>%s</b> &lt;</span>", types[sel]);

      this.selected = sel;
      this.set_markup (s);
      this.queue_draw ();
    }
  }
  /* Result List stuff */
  public class ResultBox: EventBox
  {
    private const int VISIBLE_RESULTS = 5;
    private const int ICON_SIZE = 35;
    private int mwidth;
    private bool no_results;
    
    public ResultBox (int width)
    {
      this.mwidth = width;
      no_results = true;
      build_ui();
    }
    
    private enum Column {
			IconColumn = 0,
			NameColumn = 1,
		}
		
		private TreeView view;
		ListStore results;
		
    private void build_ui()
    {
      var vbox = new VBox (false, 0);
      vbox.border_width = 1;
      this.add (vbox);
      var resultsScrolledWindow = new ScrolledWindow (null, null);
      resultsScrolledWindow.set_policy (PolicyType.NEVER, PolicyType.NEVER);
      vbox.pack_start (resultsScrolledWindow);
      
      view = new TreeView ();
			view.enable_search = false;
			view.headers_visible = false;
			// If this is not set the tree will call IconDataFunc for all rows to 
			// determine the total height of the tree
			view.fixed_height_mode = true;
			resultsScrolledWindow.add (view);
			view.show();
      // Model
      view.model = results = new ListStore(2, typeof(GLib.Icon), typeof(string));

      var column = new TreeViewColumn ();
			column.sizing = Gtk.TreeViewColumnSizing.FIXED;

			var crp = new CellRendererPixbuf ();
      crp.set_fixed_size (ICON_SIZE, ICON_SIZE);
      crp.stock_size = IconSize.DND;
			column.pack_start (crp, false);
			column.add_attribute (crp, "gicon", (int) Column.IconColumn);
			
			var ctxt = new CellRendererText ();
			ctxt.ellipsize = Pango.EllipsizeMode.END;
			ctxt.set_fixed_size (mwidth - ICON_SIZE, ICON_SIZE);
			column.pack_start (ctxt, false);
      column.add_attribute (ctxt, "markup", (int) Column.NameColumn);
      
      view.append_column (column);
    }    
    public void update_matches (Gee.List<Sezen.Match>? rs)
    {
      results.clear();
      if (rs==null)
      {
        no_results = true;
        return;
      }
      no_results = false;
      TreeIter iter;
      foreach (Match m in rs)
      {
        results.append (out iter);
        results.set (iter, Column.IconColumn, GLib.Icon.new_for_string(m.icon_name), Column.NameColumn, 
                     Markup.printf_escaped ("<span><b>%s</b></span>\n<span size=\"small\">%s</span>",m.title, m.description));
      }
      var sel = view.get_selection ();
      sel.select_path (new TreePath.first());
    }
    public int move_selection (int val)
    {
      if (no_results)
        return -1;
      var sel = view.get_selection ();
      int index = -1, oindex = -1;
      GLib.List<TreePath> sel_paths = sel.get_selected_rows(null);
      TreePath path = sel_paths.first ().data;
      TreePath opath = path;
      try {oindex = path.to_string().to_int();} catch {}
      if (val > 0)
        path.next ();
      else if (val < 0)
        path.prev ();
      try {
        index = path.to_string().to_int();
      } catch {}
      if (index < 0 || index >= results.length)
      {
        index = oindex;
        path = opath;
      }
      /* Scroll to path */
      var time = new TimeoutSource(1);
      time.set_callback(() => {
          sel.unselect_all ();
          sel.select_path (path);
          view.scroll_to_cell (path, null, true, 0.5F, 0.0F);
          return false;
      });
      time.attach(null);
      return index;
    }
  }

  public class SezenIconProvider
  {
    public static Gdk.Pixbuf get_icon_pixbuf (string name, int size)
    {
      Gdk.Pixbuf pixbuf = null;
			string name_noext;

      IconTheme theme = IconTheme.get_default();

			try	{
				if (theme.has_icon (name)) {  
					pixbuf = theme.load_icon (name, size, 0);
				} else if (name == "gnome-mime-text-plain" && theme.has_icon ("gnome-mime-text")) { 
					pixbuf = theme.load_icon ("gnome-mime-text", size, 0);
				}
			} catch {
				pixbuf = null;
			}
		
			return pixbuf;
    }
  }
}