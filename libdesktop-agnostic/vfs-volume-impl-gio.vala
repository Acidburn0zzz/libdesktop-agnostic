/*
 * Desktop Agnostic Library: VFS Volume implementation (GIO).
 *
 * Copyright (C) 2009 Mark Lee <libdesktop-agnostic@lazymalevolence.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 *
 * Author : Mark Lee <libdesktop-agnostic@lazymalevolence.com>
 */

using DesktopAgnostic.VFS;

namespace DesktopAgnostic.VFS.Volume
{
  public class GIOBackend : Object, Backend
  {
    private GLib.Volume vol;
    public GLib.Volume implementation
    {
      construct
      {
        this.vol = value;
      }
    }
    public string name
    {
      get
      {
        return this.vol.get_name ();
      }
    }
    private File.Backend _uri;
    public File.Backend uri
    {
      get
      {
        if (this._uri == null)
        {
          GLib.File file = this.vol.get_mount ().get_root ();
          this._uri = (File.Backend)Object.new (vfs_get_default ().file_type,
                                                "uri", file.get_uri ());
        }
        return this._uri;
      }
    }
    private string? _icon;
    public string? icon
    {
      get
      {
        if (this._icon == null)
        {
          GLib.Icon icon = this.vol.get_icon ();
          if (icon is GLib.ThemedIcon)
          {
            unowned string[] icon_names = ((GLib.ThemedIcon)icon).names;
            if (icon_names.length > 0)
            {
              this._icon = icon_names[0];
            }
            else
            {
              // set fallback
              warning ("Could not find any icon names.");
              this._icon = "drive-harddisk";
            }
          }
          else if (icon is GLib.FileIcon)
          {
            string path = ((GLib.FileIcon)icon).get_file ().get_path ();
            this._icon = path;
          }
          else
          {
            // set fallback
            warning ("Unknown icon type: %s", icon.get_type ().name ());
            this._icon = "drive-harddisk";
          }
        }
        return this._icon;
      }
    }
    public bool
    is_mounted ()
    {
      return this.vol.get_mount () != null;
    }
    private Volume.Callback _mount_callback;
    private AsyncResult async_result;
    private void on_mount (Object obj, AsyncResult res)
    {
      this.async_result = res;
      this._mount_callback (this);
      this._mount_callback = null;
    }
    public void
    mount (Volume.Callback callback)
    {
      if (this._mount_callback == null)
      {
        this._mount_callback = callback;
        this.vol.mount (MountMountFlags.NONE, null, null, this.on_mount);
      }
    }
    public bool mount_finish () throws Volume.Error
    {
      bool result = false;
      try
      {
        result = this.vol.mount_finish (this.async_result);
      }
      catch (GLib.Error err)
      {
        throw new Volume.Error.MOUNT (err.message);
      }
      this.async_result = null;
      return result;
    }
    private Volume.Callback _unmount_callback;
    private void on_unmount (Object obj, AsyncResult res)
    {
      this.async_result = res;
      this._unmount_callback (this);
      this._unmount_callback = null;
    }
    public void
    unmount (Volume.Callback callback)
    {
      if (this._unmount_callback == null)
      {
        this._unmount_callback = callback;
        this.vol.get_mount ().unmount (MountUnmountFlags.NONE, null,
                                       this.on_unmount);
      }
    }
    public bool unmount_finish () throws Volume.Error
    {
      bool result = false;
      try
      {
        result = this.vol.get_mount ().unmount_finish (this.async_result);
      }
      catch (GLib.Error err)
      {
        throw new Volume.Error.UNMOUNT (err.message);
      }
      this.async_result = null;
      return result;
    }
    public bool
    can_eject ()
    {
      return this.vol.can_eject ();
    }
    private Volume.Callback _eject_callback;
    private void
    on_eject (Object obj, AsyncResult res)
    {
      this.async_result = res;
      this._eject_callback (this);
      this._eject_callback = null;
    }
    public void
    eject (Volume.Callback callback)
    {
      if (this._eject_callback == null)
      {
        this._eject_callback = callback;
        this.vol.eject (MountUnmountFlags.NONE, null, this.on_eject);
      }
    }
    public bool eject_finish () throws Volume.Error
    {
      bool result = false;
      try
      {
        result = this.vol.eject_finish (this.async_result);
      }
      catch (GLib.Error err)
      {
        throw new Volume.Error.EJECT (err.message);
      }
      this.async_result = null;
      return result;
    }
  }
  public class GIOMonitor : Object, Monitor
  {
    private VolumeMonitor monitor;
    private HashTable<GLib.Volume,Backend> _volumes;
    construct
    {
      this.monitor = VolumeMonitor.get ();
      this._volumes = new HashTable<GLib.Volume,Backend> (direct_hash,
                                                          direct_equal);
      unowned List<GLib.Volume> vols = this.monitor.get_volumes ();
      foreach (unowned GLib.Volume gvol in vols)
      {
        Volume.Backend vol = this.create_volume (gvol);
        this._volumes.insert (gvol, vol);
      }
      this.monitor.mount_added += this.on_mount_added;
      this.monitor.mount_removed += this.on_mount_removed;
      this.monitor.volume_added += this.on_volume_added;
      this.monitor.volume_removed += this.on_volume_removed;
    }
    private Backend
    create_volume (GLib.Volume vol)
    {
        return (Backend)Object.new (typeof (GIOBackend),
                                    "implementation", vol);
    }
    private Backend
    check_volume (GLib.Volume gvol)
    {
      Backend? vol = this._volumes.lookup (gvol);
      if (vol == null)
      {
        vol = this.create_volume (gvol);
        this._volumes.insert (gvol, vol);
      }
      return vol;
    }
    private Backend
    get_volume_from_mount (Mount mount)
    {
      return this.check_volume (mount.get_volume ());
    }
    private void
    on_mount_added (VolumeMonitor vmonitor, Mount mount)
    {
      this.volume_mounted (this.get_volume_from_mount (mount));
    }
    private void
    on_mount_removed (VolumeMonitor vmonitor, Mount mount)
    {
      this.volume_unmounted (this.get_volume_from_mount (mount));
    }
    private void
    on_volume_added (VolumeMonitor vmonitor, GLib.Volume gvol)
    {
      this.check_volume (gvol);
    }
    private void
    on_volume_removed (VolumeMonitor vmonitor, GLib.Volume gvol)
    {
      Backend? vol = this._volumes.lookup (gvol);
      if (vol != null)
      {
        this._volumes.remove (gvol);
      }
    }
    public void* implementation
    {
      get
      {
        return (void*)this.monitor;
      }
    }
    public List<Backend> volumes
    {
      owned get
      {
        return this._volumes.get_values ();
      }
    }
  }
}

// vim: set et ts=2 sts=2 sw=2 ai :
