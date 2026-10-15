# Read-only WPD metadata query; requests only model and firmware, never serial/IMEI.
# Definitions checked against Microsoft's WinSDK RecompiledIdlHeaders.
$ErrorActionPreference='Stop'
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
namespace TabletDiagnostics {
 [StructLayout(LayoutKind.Sequential)] public struct Key { public Guid fmtid; public uint pid; public Key(string g,uint p){fmtid=new Guid(g);pid=p;} }
 [ComImport,Guid("a1567595-4c2f-4574-a6fa-ecef917b9a40"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface Manager {
 [PreserveSig] int GetDevices([Out,MarshalAs(UnmanagedType.LPArray,SizeParamIndex=1)] IntPtr[] ids,ref uint count);
 }
 [ComImport,Guid("625e2df8-6392-4cf0-9ad1-3cfa5f17775c"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface Device {
 [PreserveSig] int Open([MarshalAs(UnmanagedType.LPWStr)] string id,Values info);
 [PreserveSig] int SendCommand(uint f,Values v,out Values r);
 [PreserveSig] int Content(out Content c);
 [PreserveSig] int Capabilities(out IntPtr c);
 [PreserveSig] int Cancel();
 [PreserveSig] int Close();
 }
 [ComImport,Guid("6a96ed84-7c73-4480-9938-bf5af477d426"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface Content {
 [PreserveSig] int EnumObjects(uint flags,[MarshalAs(UnmanagedType.LPWStr)]string id,Values filter,out IntPtr e);
 [PreserveSig] int Properties(out Properties p);
 }
 [ComImport,Guid("7f6d695c-03df-4439-a809-59266beee3a6"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface Properties {
 [PreserveSig] int GetSupportedProperties([MarshalAs(UnmanagedType.LPWStr)]string id,out Keys keys);
 [PreserveSig] int GetPropertyAttributes([MarshalAs(UnmanagedType.LPWStr)]string id,ref Key key,out Values values);
 [PreserveSig] int GetValues([MarshalAs(UnmanagedType.LPWStr)]string id,Keys keys,out Values values);
 }
 [ComImport,Guid("dada2357-e0ad-492e-98db-dd61c53ba353"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface Keys {
 [PreserveSig] int GetCount(out uint count);
 [PreserveSig] int GetAt(uint index,out Key key);
 [PreserveSig] int Add(ref Key key);
 }
 [ComImport,Guid("6848f6f2-3155-4f86-b6f5-263eeeab3143"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface Values {
 [PreserveSig] int GetCount(out uint count);
 [PreserveSig] int GetAt(uint index,IntPtr key,IntPtr value);
 [PreserveSig] int SetValue(ref Key key,IntPtr value);
 [PreserveSig] int GetValue(ref Key key,IntPtr value);
 [PreserveSig] int SetStringValue(ref Key key,[MarshalAs(UnmanagedType.LPWStr)]string value);
 [PreserveSig] int GetStringValue(ref Key key,out IntPtr value);
 [PreserveSig] int SetUnsignedIntegerValue(ref Key key,uint value);
 }
 public static class Reader {
 static object New(string id){return Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid(id)));}
 static void Check(int h){Marshal.ThrowExceptionForHR(h);}
 static string Get(Values values,Key key){IntPtr p; int h=values.GetStringValue(ref key,out p); if(h<0)return "Unavailable (0x"+h.ToString("X8")+")"; try{return Marshal.PtrToStringUni(p);}finally{Marshal.FreeCoTaskMem(p);}}
 public static string[] Read(){var result=new List<string>(); Manager manager=(Manager)New("0af10cec-2ecd-4b92-9581-34f6ae0637f3"); uint count=0; Check(manager.GetDevices(null,ref count)); IntPtr[] ids=new IntPtr[count]; Check(manager.GetDevices(ids,ref count));
 try {for(int i=0;i<count;i++){Device device=null; Values info=null; Keys keys=null; Content content=null; Properties props=null; Values values=null;
 try { string id=Marshal.PtrToStringUni(ids[i]); if(id.IndexOf("VID_04E8",StringComparison.OrdinalIgnoreCase)<0)continue;
 device=(Device)New("f7c0039a-4762-488a-b4b3-760ef9a1ba9b"); info=(Values)New("0c15d503-d017-47ce-9016-7b3f978721cc"); var access=new Key("204d9f0c-2292-4080-9f42-40664e70f859",9); Check(info.SetUnsignedIntegerValue(ref access,0x80000000)); Check(device.Open(id,info));
 Check(device.Content(out content)); Check(content.Properties(out props)); keys=(Keys)New("de2d022d-2480-43be-97f0-d1fa2cf98f4f"); var model=new Key("26d4979a-e643-4626-9e2b-736dc0c92fdc",8); var fw=new Key("26d4979a-e643-4626-9e2b-736dc0c92fdc",3); Check(keys.Add(ref model)); Check(keys.Add(ref fw)); Check(props.GetValues("DEVICE",keys,out values)); result.Add("Model: "+Get(values,model)); result.Add("Firmware: "+Get(values,fw));
 } catch(Exception e){ result.Add("WPD query error: "+e.GetType().Name+" (0x"+e.HResult.ToString("X8")+")"); }
 finally{if(device!=null)device.Close(); foreach(object o in new object[]{values,props,content,keys,info,device})if(o!=null)Marshal.FinalReleaseComObject(o);}
 }} finally{foreach(IntPtr p in ids)if(p!=IntPtr.Zero)Marshal.FreeCoTaskMem(p);Marshal.FinalReleaseComObject(manager);} return result.ToArray(); }
 }
}
"@
[TabletDiagnostics.Reader]::Read()
