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
  public class SezenWindow : UIInterface
  {
    Window window;
    Window result_window;
    /* Main UI shared components */
    private Image main_image = null;
    private Image main_image_overlay = null;
    private Label main_label = null;
    private Label main_label_description = null;
    private Image action_image = null;
    private Label action_label = null;
    private HSelectionContainer sts = null;
    private HBox top_hbox = null;
    private HBox right_hbox = null;
    private VBox container = null;
    private VBox top_vbox = null;
    private VBox titles_vbox = null;
    private ContainerOverlayed gco_main = null;
    private ResultBox result_box = null; //FIXME DELETE
    
    private const int UI_WIDTH = 600; // height is dynamic
    private const int PADDING = 10; // assinged to top_vbox's border width
    private const int SHADOW_SIZE = 12; // assigned to window's border width in composited
    private const int BORDER_RADIUS = 20;
    private const int ICON_SIZE = 172;
    private const int ACTION_ICON_SIZE = 64;
    private const int TOP_SPACING = ICON_SIZE * 2 / 5;
    
    private string[] categories = {"Actions", "Audio", "Applications", "All", "Documents", "Images", "Video", "Internet"};
    private QueryFlags[] categories_query = {QueryFlags.ACTIONS, QueryFlags.AUDIO, QueryFlags.APPLICATIONS, QueryFlags.ALL,
                                             QueryFlags.DOCUMENTS, QueryFlags.IMAGES, QueryFlags.VIDEO, QueryFlags.INTERNET};

    /* STATUS */
    private bool list_visible = true;
    private IMContext im_context;
    
    public SezenWindow ()
    {
      window = new Window ();
      window.set_position (WindowPosition.CENTER);
      window.set_decorated (false);
      window.set_resizable (false);
      
      result_window = new Window ();
      result_window.set_position (WindowPosition.NONE);
      result_window.set_decorated (false);
      result_window.set_resizable (false);
      result_window.skip_taskbar_hint = true;
      result_window.skip_pager_hint = true;
      
      /* FIXME: Why this events doesn't work? */
      result_window.set_events (Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK);
      result_window.button_press_event.connect (result_window_click);
      result_window.button_release_event.connect (result_window_click);

      build_ui ();

      Utils.ensure_transparent_bg (window);
      window.expose_event.connect (on_expose);
      on_composited_changed (window);
      window.composited_changed.connect ((w) => { Timeout.add (1000, () => {on_composited_changed (w); return false;});});

      window.key_press_event.connect (key_press_event);

      set_list_visible (false);
      
      /* SEZEN */
      focus_match (0, null);
      focus_action (0, null);

      im_context = new IMMulticontext ();
      im_context.set_use_preedit (false);
      im_context.commit.connect (search_add_char);
      im_context.focus_in ();
      
      window.key_press_event.connect (key_press_event);
    }
    
    private bool result_window_click (Widget w, Gdk.EventButton event)
    {
      debug ("pressed or released");
      Utils.unpresent_window(result_window);
      Utils.present_window(window);
      return false;
    }

    private void update_result_window_position ()
    {
      int parent_x = 0, parent_y = 0, parent_w = 0, parent_h = 0;
      int result_w = 0, result_h = 0;
      window.get_position (out parent_x, out parent_y);
      window.get_size (out parent_w, out parent_h);
      result_window.get_size (out result_w, out result_h);
      result_window.move (parent_x + (parent_w-result_w) / 2, parent_y+parent_h-(int)container.border_width);
    }
    
    private void build_ui ()
    {
      result_box = new ResultBox (400, 5);
      result_box.show_all ();
      result_window.add (result_box);
      /* Constructing Main Areas*/
      top_vbox = new VBox (false, 0);
      top_vbox.set_size_request (UI_WIDTH, -1);
      top_vbox.border_width = PADDING;
      container = new VBox (false, 0);
      container.pack_start (top_vbox);
      window.add (container);
      /* Top Hbox */
      top_hbox = new HBox (false, 0);
      /* Match Description */
      main_label_description = new Label ("descrizione");
      main_label_description.set_alignment (0, 0);
      main_label_description.set_ellipsize (Pango.EllipsizeMode.END); 
      main_label_description.set_line_wrap (true);
      /* Packing Top Hbox with Match Desctiption into Top VBox*/
      top_vbox.pack_start (top_hbox);
      top_vbox.pack_start (main_label_description, false);
      
      /* Match Icon packed into Top HBox */
      gco_main = new ContainerOverlayed();
      main_image_overlay = new Image();
      main_image_overlay.set_pixel_size (ICON_SIZE / 2);
      main_image = new Image ();
      main_image.set_size_request (ICON_SIZE, ICON_SIZE);
      main_image.set_pixel_size (ICON_SIZE);
      gco_main.main = main_image;
      gco_main.overlay = main_image_overlay;
      top_hbox.pack_start (gco_main, false);
      
      /* VBox to push down the right area */
      var top_right_vbox = new VBox (false, 0);
      top_hbox.pack_start (top_right_vbox);
      /* Spacer */
      var spacer = new Label("");
      spacer.set_size_request (-1, TOP_SPACING);
      /* STS */
      sts = new HSelectionContainer(_hilight_label, 15);
      foreach (string s in this.categories)
        sts.add (new Label(s));
      sts.select (3);
      /* HBox for titles and action icon */
      var right_hbox = new HBox (false, 0);
      top_right_vbox.pack_start (spacer, false);
      top_right_vbox.pack_start (sts, false);
      top_right_vbox.pack_start (right_hbox);
      
      /* Titles box and Action icon*/
      var labels_vbox = new VBox (false, 0); //FIXME: Omogeneus?
      action_image = new Image ();
      action_image.set_pixel_size (ACTION_ICON_SIZE);
      action_image.set_alignment (0.5f, 0.5f);
      action_image.set_size_request (ACTION_ICON_SIZE, ACTION_ICON_SIZE);

      right_hbox.pack_start (labels_vbox);
      right_hbox.pack_start (action_image, false);
      
      main_label = new Label (null);
      main_label.set_alignment (0.0f, 0.5f);
      main_label.set_ellipsize (Pango.EllipsizeMode.END);
      main_label.xpad = 10;

      action_label = new Label (null);
      action_label.set_alignment (1.0f, 0.5f);
      action_label.set_ellipsize (Pango.EllipsizeMode.START);
      action_label.xpad = 10;
      
      labels_vbox.pack_start (action_label);
      labels_vbox.pack_start (main_label);
            
      container.show_all ();
    }
    
    private void on_composited_changed (Widget w)
    {
      Gdk.Screen screen = w.get_screen ();
      bool comp = screen.is_composited ();
      Gdk.Colormap? cm = screen.get_rgba_colormap();
      if (cm == null)
      {
        comp = false;
        cm = screen.get_rgb_colormap();
      }
      debug ("Screen is%s composited.", comp?"": " NOT");
      w.set_colormap (cm);
      if (comp)
        container.border_width = SHADOW_SIZE;
      else
        container.border_width = 0;
      //window.queue_resize (); //FIXME: really not needed ?!
      set_mask (true, comp);
      set_mask (false, comp);      
    }
    
    private void set_mask (bool input, bool composited)
    {
      Requisition req = {0, 0};
      double extra = container.border_width * 2;
      top_vbox.size_request (out req);
      var bitmap = new Gdk.Pixmap (null, req.width + (int)extra, req.height + (int)extra, 1);
      var ctx = Gdk.cairo_create (bitmap);
      ctx.set_operator (Cairo.Operator.CLEAR);
      ctx.paint ();
      ctx.set_operator (Cairo.Operator.OVER);
      ctx.set_source_rgba (0, 0, 0, 1);
      if (composited && !input)
      {
        ctx.rectangle (0, 0, req.width + extra, req.height + extra);
        ctx.fill ();
      }
      else
      {
        Utils.cairo_rounded_rect (ctx, 0, 0, ICON_SIZE + PADDING * 2 + container.border_width, ICON_SIZE, BORDER_RADIUS);
        ctx.fill ();
        Utils.cairo_rounded_rect (ctx, 0, TOP_SPACING, req.width + extra, req.height-TOP_SPACING + extra, BORDER_RADIUS);
        ctx.fill ();
      }
      if (input)
      {
        window.input_shape_combine_mask (null, 0, 0);
        window.input_shape_combine_mask ((Gdk.Bitmap*)bitmap, 0, 0);
      }
      else
      {
        window.shape_combine_mask (null, 0, 0);
        window.shape_combine_mask ((Gdk.Bitmap*)bitmap, 0, 0);
      }
    }
    
    private bool on_expose (Widget widget, Gdk.EventExpose event) {
      bool comp = widget.is_composited ();
      var ctx = Gdk.cairo_create (widget.window);
      ctx.set_operator (Operator.CLEAR);
      ctx.paint ();
      ctx.set_operator (Operator.OVER);
      double w = top_vbox.allocation.width;
      double h = top_vbox.allocation.height;
      double x = top_vbox.allocation.x;
      double y = top_vbox.allocation.y;
      Gtk.Style style = widget.get_style();
      double r = 0.0, g = 0.0, b = 0.0;
      Utils.gdk_color_to_rgb (style.bg[Gtk.StateType.NORMAL], &r, &g, &b);
      if (comp)
      {
        y += TOP_SPACING;
        h -= TOP_SPACING;
        //draw shadow
        Utils.rgb_invert_color (out r, out g, out b);
        Utils.cairo_make_shadow_for_rect (ctx, x, y, w, h, BORDER_RADIUS,
                                          r, g, b, 0.9, SHADOW_SIZE);
      }
      
      Pattern pat = new Pattern.linear(0, y, 0, y+h);
      Utils.gdk_color_to_rgb (style.bg[Gtk.StateType.NORMAL], &r, &g, &b);
      pat.add_color_stop_rgba (0, double.min(r + 0.15, 1),
                                  double.min(g + 0.15, 1),
                                  double.min(b + 0.15, 1),
                                  0.95);
      pat.add_color_stop_rgba (1, double.max(r - 0.15, 0),
                                  double.max(g - 0.15, 0),
                                  double.max(b - 0.15, 0),
                                  0.95);
      _cairo_path_for_main (ctx, comp, x, y, w, h);
      ctx.set_source (pat);
      ctx.fill ();
      if (!comp)
      {
        Utils.rgb_invert_color (out r, out g, out b);
        _cairo_path_for_main (ctx, comp, x, y, w, h);
        ctx.set_source_rgba (r, g, b, 1.0);
        ctx.set_line_width (3.5);
        ctx.stroke (); 
      }
      /* Propagate Expose */               
      Bin c = (widget is Bin) ? (Bin) widget : null;
      if (c != null)
        c.propagate_expose (c.get_child(), event);
      return true;
    }

    private void _cairo_path_for_main (Cairo.Context ctx, bool composited,
                                       double x, double y, double w, double h)
    {
      

      if (composited)
        Utils.cairo_rounded_rect (ctx, x, y, w, h, BORDER_RADIUS);
      else
      {
        /*
         __               y1
        |  |_______________ y2
        |                  |
        |__________________|y3
        x1 x3            x4
        */
        double x1 = x,
               x3 = x + PADDING * 2 + ICON_SIZE,
               x4 = w,
               y1 = y,
               y2 = y + TOP_SPACING,
               y3 = y + h,
               r = BORDER_RADIUS;
        ctx.move_to (x1, y3 - r);
        ctx.arc (x1+r, y1+r, r, Math.PI, Math.PI * 1.5);
        ctx.arc (x3-r, y1+r, r, Math.PI * 1.5, Math.PI * 2.0);
        ctx.line_to (x3, y2);
        ctx.arc (x4-r, y2+r, r, Math.PI * 1.5, Math.PI * 2.0);
        ctx.arc (x4-r, y3-r, r, 0, Math.PI * 0.5);
        ctx.arc (x1+r, y3-r, r, Math.PI * 0.5, Math.PI);
      }
    }
    
    public void show ()
    {
      window.show ();
    }
    public void hide ()
    {
      window.hide ();
    }
    private static void _hilight_label (Widget w, bool b)
    {
      Label l = (Label) w;
      if (b)
      {
        string s = l.get_text();
        l.set_markup (Markup.printf_escaped ("<span size=\"large\"><b>%s</b></span>", s));
        l.sensitive = true;
      }
      else
      {
        string s = l.get_text();
        l.set_markup (Markup.printf_escaped ("<span size=\"small\">%s</span>", s));
        l.sensitive = false;
      }
    }
    bool searching_for_matches = true;
    
    /* EVENTS HANDLING HERE */
    private void search_add_char (string chr)
    {
      if (searching_for_matches)
        set_match_search (get_match_search() + chr);
      else
        set_action_search (get_action_search() + chr);
    }
    private void search_delete_char ()
    {
      string s = "";
      if (searching_for_matches)
        s = get_match_search ();
      else
        s = get_action_search ();
      long len = s.length;
      if (len > 0)
      {
        s = s.substring (0, len - 1);
        if (searching_for_matches)
          set_match_search (s);
        else
          set_action_search (s);
      }
    }
    
    private void hide_and_reset ()
    {
      window.hide ();
      set_list_visible (false);
      sts.select (3);
      reset_search ();
    }
    
    public void present_with_time (uint32 timestamp)
    {
      window.present_with_time (timestamp);
    }
    
    protected bool key_press_event (Gdk.EventKey event)
    {
      if (im_context.filter_keypress (event)) return true;

      uint key = event.keyval;
      switch (key)
      {
        case Gdk.KeySyms.Return:
        case Gdk.KeySyms.KP_Enter:
        case Gdk.KeySyms.ISO_Enter:
          debug ("enter pressed");
          if (execute ())
            hide_and_reset ();
          break;
        case Gdk.KeySyms.Delete:
        case Gdk.KeySyms.BackSpace:
          search_delete_char ();
          break;
        case Gdk.KeySyms.Escape:
          debug ("escape");
          if (!searching_for_matches)
          {
            set_action_search ("");
            searching_for_matches = true;
            window.queue_draw ();
          }
          else if (get_match_search() != "")
          {
            set_match_search("");
            set_list_visible (false);
          }
          else
          {
            hide_and_reset ();
          }
          break;
        case Gdk.KeySyms.Left:
          sts.select_prev ();
          if (!searching_for_matches)
          {
            searching_for_matches = true;
            window.queue_draw ();
          }
          update_query_flags (this.categories_query[sts.get_selected()]);
          break;
        case Gdk.KeySyms.Right:
          sts.select_next ();
          if (!searching_for_matches)
          {
            searching_for_matches = true;
            window.queue_draw ();
          }
          update_query_flags (this.categories_query[sts.get_selected()]);
          break;
        case Gdk.KeySyms.Up:
          bool b = true;
          if (searching_for_matches)
            b = select_prev_match ();
          else
            b = select_prev_action ();
          if (!b)
            set_list_visible (false);
          break;
        case Gdk.KeySyms.Down:
          if (!list_visible)
          {
            set_list_visible (true);
            return true;
          }
          if (searching_for_matches)
            select_next_match ();
          else
            select_next_action ();
          set_list_visible (true);
          break;
        case Gdk.KeySyms.Tab:
          if (searching_for_matches && 
              (get_match_results () == null || get_match_results ().size == 0))
            return true;
          searching_for_matches = !searching_for_matches;
          Match m = null;
          int i = 0;
          if (searching_for_matches)
          {
            get_match_focus (out i, out m);
            update_match_result_list (get_match_results (), i, m);
            get_action_focus (out i, out m);
            focus_action (i, m);
          }
          else
          {
            get_match_focus (out i, out m);
            focus_match (i, m); 
            get_action_focus (out i, out m);
            update_action_result_list (get_action_results (), i, m);
          }
          window.queue_draw ();
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
      if (b)
      {
        this.update_result_window_position ();
        result_window.show();
        Utils.unpresent_window (result_window);
        Utils.present_window (window);
      }
      else
      {
        result_window.hide();
        Utils.present_window (window);
      }
    }   
    
    private string markup_string_with_search (string text, string pattern, string size = "xx-large")
    {
      if (pattern == "")
      {
        return Markup.printf_escaped ("<span size=\"%s\">%s</span>", size, text);
      }
      // if no text found, use pattern
      if (text == "")
      {
        return Markup.printf_escaped ("<span size=\"%s\">%s<b> </b></span>", size, pattern);
      }

      var matchers = Query.get_matchers_for_query (
                        Markup.escape_text (pattern), 0,
                        RegexCompileFlags.OPTIMIZE | RegexCompileFlags.CASELESS);
      string? highlighted = null;
      string escaped_text = Markup.escape_text (text);
      foreach (var matcher in matchers)
      {
        if (matcher.key.match (escaped_text))
        {
          highlighted = matcher.key.replace_eval (escaped_text, -1, 0, 0, (mi, res) =>
          {
            int start_pos;
            int end_pos;
            int last_pos = 0;
            int cnt = mi.get_match_count ();
            for (int i = 1; i < cnt; i++)
            {
              mi.fetch_pos (i, out start_pos, out end_pos);
              if (i > 1) res.append (escaped_text.substring (last_pos, start_pos - last_pos));
              last_pos = end_pos;
              res.append ("<u><b>%s</b></u>".printf (mi.fetch (i)));
            }
          });
          break;
        }
      }
      if (highlighted != null)
      {
        return "<span size=\"%s\">%s</span>".printf (size,highlighted);
      }
      else
      {
        return Markup.printf_escaped ("<span size=\"%s\">%s</span>", size, text);
      }
    }

    private string get_description_markup (string s)
    {
      return Markup.printf_escaped ("<span size=\"medium\">%s</span>", s);
    }
    
    /* UI INTERFACE IMPLEMENTATION */
    protected override void focus_match ( int index, Match? match )
    {
      string size = searching_for_matches ? "xx-large": "medium";
      if (match == null)
      {
        /* Show default stuff */
        if (get_match_search () != "")
        {
          main_label.set_markup (markup_string_with_search ("", get_match_search (), size));
          main_label_description.set_markup (get_description_markup ("Match not found."));
          main_image.set_from_icon_name ("search", IconSize.DIALOG);
          main_image_overlay.clear ();
        }
        else
        {
          main_image.set_from_icon_name ("search", IconSize.DIALOG);
          main_image_overlay.clear ();
          main_label.set_markup (
            Markup.printf_escaped ("<span size=\"xx-large\">%s</span>",
                                   "Type to search..."));
          main_label_description.set_markup (
            Markup.printf_escaped ("<span size=\"medium\"> </span>" +
                                   "<span size=\"smaller\">%s</span>",
                                   "Powered by Zeitgeist"));
        }
      }
      else
      {
        try
        {
          main_image.set_from_gicon (GLib.Icon.new_for_string (match.icon_name), IconSize.DIALOG);
          if (match.has_thumbnail)
            main_image_overlay.set_from_gicon (GLib.Icon.new_for_string (match.thumbnail_path), IconSize.DIALOG);
          else
            main_image_overlay.clear ();
        }
        catch (Error err)
        {
          main_image.set_from_icon_name ("missing-image", IconSize.DIALOG);
          main_image_overlay.clear ();
        }
        main_label.set_markup (markup_string_with_search (match.title, get_match_search (), size));
        main_label_description.set_markup (get_description_markup (match.description));
        result_box.move_selection_to_index (index);
      }
    }
    protected override void focus_action ( int index, Match? action )
    {
      string size = !searching_for_matches ? "xx-large": "medium";
      if (action == null)
      {
        action_image.set_sensitive (false);
        action_image.set_from_icon_name ("system-run", IconSize.DIALOG);
        action_label.set_markup (markup_string_with_search ("", get_action_search(), size));
      }
      else
      {
        action_image.set_sensitive (true);
        try
        {
          action_image.set_from_gicon (GLib.Icon.new_for_string (action.icon_name), IconSize.DIALOG);
        }
        catch (Error err)
        {
          action_image.set_from_icon_name ("missing-image", IconSize.DIALOG);
        }
        action_label.set_markup (markup_string_with_search (action.title,
                                 searching_for_matches ? 
                                 "" : get_action_search (), size));
        if (!searching_for_matches)
        {
          result_box.move_selection_to_index (index);
        }
      }
    }
    protected override void update_match_result_list (Gee.List<Match>? matches, int index, Match? match)
    {
      if (searching_for_matches)
      {
        result_box.update_matches (matches);
        if (matches == null || matches.size == 0)
          set_list_visible (false);
      }
      focus_match ( index, match );
    }
    protected override void update_action_result_list (Gee.List<Match>? actions, int index, Match? action)
    {
      if (!searching_for_matches)
      {
        result_box.update_matches (actions);
        if (actions == null || actions.size == 0)
          set_list_visible (false);
      }
      focus_action (index, action);
    }
    
    public static int main (string[] argv)
    {
      Gtk.init (ref argv);
      var window = new SezenWindow ();
      window.show ();

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
          window.show();
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
  
  /* Result List stuff */
  public class ResultBox: EventBox
  {
    private const int VISIBLE_RESULTS = 5;
    private const int ICON_SIZE = 35;
    private int mwidth;
    private int nrows;
    private bool no_results;
    private HBox status_box;
    
    public ResultBox (int width, int nrows = 5)
    {
      this.mwidth = width;
      this.nrows = nrows;
      no_results = true;
      build_ui();
    }
    
    private enum Column {
			IconColumn = 0,
			NameColumn = 1,
		}
		
		private TreeView view;
		ListStore results;
		private Label status;
		
		private bool on_expose (Widget w, Gdk.EventExpose event) {
        var ctx = Gdk.cairo_create (w.window);
        /* Clear Stage */
        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();
        ctx.set_operator (Cairo.Operator.OVER);

        /* Prepare bg's colors using GtkStyle */
        Gtk.Style style = w.get_style();
        double r = 0.0, g = 0.0, b = 0.0;
        Pattern pat = new Pattern.linear(0, 0, 0, w.allocation.height);
        Utils.gdk_color_to_rgb (style.bg[Gtk.StateType.NORMAL], &r, &g, &b);
        pat.add_color_stop_rgba (1.0 - 15.0 / w.allocation.height, double.min(r + 0.15, 1),
                                    double.min(g + 0.15, 1),
                                    double.min(b + 0.15, 1),
                                    0.95);
        pat.add_color_stop_rgba (1, double.max(r - 0.15, 0),
                                    double.max(g - 0.15, 0),
                                    double.max(b - 0.15, 0),
                                    0.95);
        /* Prepare and draw top bg's rect */
        ctx.rectangle (0, 0, w.allocation.width, w.allocation.height);
        ctx.set_source (pat);
        ctx.fill ();

        /* Propagate Expose */               
        Container c = (w is Container) ? (Container) w : null;
        if (c != null)
          c.propagate_expose (this.get_child(), event);
        
        return true;
    }
		
    private void build_ui()
    {
      var vbox = new VBox (false, 0);
      this.expose_event.connect (on_expose);
      vbox.border_width = 1;
      this.add (vbox);
      var resultsScrolledWindow = new ScrolledWindow (null, null);
      resultsScrolledWindow.set_policy (PolicyType.NEVER, PolicyType.NEVER);
      vbox.pack_start (resultsScrolledWindow);
      var status_box = new HBox (false, 0);
      status_box.set_size_request (-1, 15);
      vbox.pack_start (status_box, false);
      status = new Label ("");
      status.set_alignment (0, 0);
      status.set_markup (Markup.printf_escaped ("<b>%s</b>", "No results."));
      var logo = new Label ("");
      logo.set_alignment (1, 0);
      logo.set_markup (Markup.printf_escaped ("<i>Sezen 2 </i>"));
      status_box.pack_start (status, true, true, 10);
      status_box.pack_start (logo, false, false, 10);
      
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
      
      Requisition requisition = {0, 0};
      status_box.size_request (out requisition);
      requisition.width = mwidth;
      requisition.height += nrows * (ICON_SIZE + 4) + 2;
      vbox.set_size_request (requisition.width, requisition.height); 
    }

    public void update_matches (Gee.List<Sezen.Match>? rs)
    {
      results.clear();
      if (rs==null)
      {
        no_results = true;
        status.set_markup (Markup.printf_escaped ("<b>%s</b>", "No results."));
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
      status.set_markup (Markup.printf_escaped ("<b>1 of %d</b>", results.length));
    }
    public void move_selection_to_index (int i)
    {
      var sel = view.get_selection ();
      Gtk.TreePath path = new TreePath.from_string( i.to_string() );
      /* Scroll to path */
      Timeout.add(1, () => {
          sel.unselect_all ();
          sel.select_path (path);
          view.scroll_to_cell (path, null, true, 0.5F, 0.0F);
          return false;
      });
      status.set_markup (Markup.printf_escaped ("<b>%d of %d</b>", i + 1, results.length));
    }
    public int move_selection (int val, out int old_index)
    {
      if (no_results)
        return -1;
      var sel = view.get_selection ();
      int index = -1, oindex = -1;
      GLib.List<TreePath> sel_paths = sel.get_selected_rows(null);
      TreePath path = sel_paths.first ().data;
      TreePath opath = path;
      oindex = path.to_string().to_int();
      old_index = oindex;
      if (val == 0)
        return oindex;
      if (val > 0)
        path.next ();
      else if (val < 0)
        path.prev ();
      
      index = path.to_string().to_int();
      if (index < 0 || index >= results.length)
      {
        index = oindex;
        path = opath;
      }
      /* Scroll to path */
      Timeout.add(1, () => {
          sel.unselect_all ();
          sel.select_path (path);
          view.scroll_to_cell (path, null, true, 0.5F, 0.0F);
          return false;
      });
      
      return index;
    }
  }


  public class ContainerOverlayed: Gtk.Container
  {
    public float scale {get; set; default = 0.25f;}
    private Widget _main = null;
    private Widget _overlay = null;
    public Widget main { get {return _main;}
                         set {
                               if(_main!=null)
                               {
                                 _main.unparent();
                                 _main = null;
                               }
                               if(value!=null)
                               {
                                 _main = value;
                                 _main.set_parent(this);
                               }
                             }
                       }
    public Widget overlay  { get {return _overlay;}
                             set {
                                   if(_overlay!=null)
                                   {
                                     _overlay.unparent();
                                     _overlay = null;
                                   }
                                   if(value!=null)
                                   {
                                     _overlay = value;
                                     _overlay.set_parent(this);
                                   }
                                 }
                           }
    public ContainerOverlayed ()
    {
      set_has_window(false);
      set_redraw_on_allocate(false);
    }
    public override void size_request (out Requisition requisition)
    {
      Requisition req = {0, 0};
      requisition.width = 1;
      requisition.height = 1;
      if (main != null)
      {
        main.size_request (out req);
        requisition.width = int.max(req.width, requisition.width);
        requisition.height = int.max(req.height, requisition.height);
      }
      if (overlay != null)
      {
        overlay.size_request (out req);
        requisition.width = int.max(req.width, requisition.width);
        requisition.height = int.max(req.height, requisition.height);
      }
    }
    public override void size_allocate (Gdk.Rectangle allocation)
    {
      Gdk.Rectangle aoverlay = {allocation.x,
                                allocation.y + allocation.height / 2,
                                allocation.width / 2,
                                allocation.height / 2
                                };
      Allocation alloc = {allocation.x, allocation.y, allocation.width, allocation.height};
      set_allocation (alloc);    
      main.size_allocate (allocation);
      overlay.size_allocate (aoverlay);
    }
    public override void forall_internal (bool b, Gtk.Callback callback)
    {
      if (main != null)
        callback (main);
      if (overlay != null)
        callback (overlay);
    }

    public override void add (Widget widget)
    {
      if (main == null)
      {
        main = widget;
      }
      else if (overlay == null)
      {
        overlay = widget;
      }
    }
    public override void remove (Widget widget)
    {
      if (overlay == widget)
      {
        widget.unparent ();
        overlay = null;
        return;
      }
      if (main == widget)
      {
        widget.unparent ();
        main = null;
      }
    }
  }
  
  /* HSelectionContainer */
  public class HSelectionContainer: Gtk.Container
  {
    public delegate void SelectWidget (Widget w, bool select);
    private ArrayList<Widget> childs;
    
    private SelectWidget func;
    private int padding;
    private int selection = 0;
    private int[] allocations = {};
    private bool[] visibles = {};
    private bool direction = true;
    private HSeparator sep;
    
    public enum SelectionAlign
    {
      LEFT = 0,
      CENTER = 1,
      RIGHT = 2
    }
    private int align;
    
    
    public HSelectionContainer (SelectWidget? func, int padding)
    {
      this.func = func;
      this.padding = padding;
      this.align = SelectionAlign.CENTER;
      childs = new ArrayList<Widget>();
      set_has_window(false);
      set_redraw_on_allocate(false);
      sep = new HSeparator();
      sep.set_parent (this);
      sep.show ();
    }
    
    public void set_selection_align (SelectionAlign align)
    {
      this.align = align;
    }
    
    public void select_next_circular ()
    {
      int sel = selection;
      sel += direction ? 1 : -1;
      if (sel < 0)
      {
        sel = 1;
        direction = true;
      }
      else if (sel >= childs.size)
      {
        sel = childs.size - 2;
        direction = false;
      }
      select (sel);
    }
    public void select_next () {select(selection+1);}
    public void select_prev () {select(selection-1);}
    
    public void select (int index)
    {
      if (index < 0 || childs.size <= index)
        return;
      
      if (func != null)
      {
        func (childs.get(selection), false);
        func (childs.get(index), true);
      }
      this.selection = index;
      this.queue_resize();
      foreach (Widget w in childs)
        w.queue_draw();
    }
    
    public int get_selected ()
    {
      return selection;
    }
    
    public override void size_request (out Requisition requisition)
    {
      Requisition req = {0, 0};
      requisition.width = 1;
      requisition.height = 1;
      foreach (Widget w in childs)
      {
        w.size_request (out req);
        requisition.width = int.max(req.width, requisition.width);
        requisition.height = int.max(req.height, requisition.height);
      }
      requisition.height += 4;
    }

    public override void size_allocate (Gdk.Rectangle allocation)
    {
      Allocation alloc = {allocation.x, allocation.y, allocation.width, allocation.height};
      set_allocation (alloc);
      int lastx = 0;
      Requisition req = {0, 0};
      int i = 0;
      // update relative coords
      foreach (Widget w in childs)
      {
        w.size_request (out req);
        this.allocations[i] = lastx;
        lastx += padding + req.width;
        ++i;
      }
      int offset = 0;
      switch (this.align)
      {
        case SelectionAlign.LEFT:
          offset = - allocations[selection];
          break;
        case SelectionAlign.RIGHT:
          offset = allocation.width - allocations[selection];
          childs.get (selection).size_request (out req);
          offset -= req.width;
          break;
        default:
          offset = allocation.width / 2 - allocations[selection];
          childs.get (selection).size_request (out req);
          offset -= req.width / 2;
          break;
      }
      // update widget allocations and visibility
      i = 0;
      int pos = 0;
      foreach (Widget w in childs)
      {
        w.size_request (out req);
        pos = offset + allocations[i];
        if (pos < 0 || pos + req.width > alloc.width)
        {
          visibles[i] = false;
          w.hide ();
        }
        else
        {
          visibles[i] = true;
          allocation.x = alloc.x + pos;
          allocation.width = req.width;
          allocation.height = req.height;
          allocation.y = alloc.y + (alloc.height - 4 - req.height) / 2;
          w.size_allocate (allocation);
          w.show_all ();
        }
        ++i;
      }
      allocation.x = alloc.x;
      allocation.y = alloc.y + alloc.height - 3;
      allocation.height = 2;
      allocation.width = alloc.width;
      sep.size_allocate (allocation);
    }
    public override void forall_internal (bool b, Gtk.Callback callback)
    {
      int i = 0;
      if (b)
      {
        callback (sep);
      }
      if (this.align == SelectionAlign.LEFT)
      {
        for (i = childs.size - 1; i >= 0; ++i)
        {
          if ( visibles[i] )
            callback (childs.get(i));
        }
      }
      else if (this.align == SelectionAlign.RIGHT)
      {
        foreach (Widget w in childs)
        {
          if ( visibles[i] )
            callback (w);
          ++i;
        }
      }
      else //align center
      {
        int j;
        j = i = selection;
        ArrayList<Widget> reordered = new ArrayList<Widget>();
        reordered.add (childs.get(i));
        while (j >= 0 || i < childs.size)
        {
          --j;
          ++i;
          if (j >= 0)
            reordered.add (childs.get(j));
          if (i < childs.size)
            reordered.add (childs.get(i));
        }
        for (i = reordered.size - 1; i >= 0; --i)
          callback (reordered.get(i));
      }
    }

    public override void add (Widget widget)
    {
      childs.add (widget);
      widget.set_parent (this);
      this.allocations += 0;
      this.visibles += true;
      if (childs.size==1)
      {
        this.selection = 0;
        if (func != null)
          func (widget, true);
      }
      else if (func != null)      
        func (widget, false);
    }
    
    public override void remove (Widget widget)
    {
      if (childs.remove (widget))
      {
        widget.unparent ();
        this.allocations.resize (this.allocations.length);
        this.visibles.resize (this.visibles.length);
      }
    }
  }
}
