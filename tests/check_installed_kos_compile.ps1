# Offline syntax check using the installed compiler; this does not run flight code.
# KSP bindings/mod suffixes still require an in-game check.
param([Parameter(Mandatory=$true)][string]$KspRoot)
$ErrorActionPreference = 'Stop'
$kosAssembly = [Reflection.Assembly]::LoadFrom((Join-Path $KspRoot 'GameData/kOS/Plugins/kOS.Safe.dll'))
$register = $kosAssembly.GetType('kOS.Safe.Function.FunctionManager').GetMethod('RegisterMethod')
foreach ($kosType in $kosAssembly.GetTypes()) {
    foreach ($attribute in $kosType.GetCustomAttributes($false)) {
        if ($attribute -is [kOS.Safe.Function.FunctionAttribute]) {
            $null = $register.Invoke($null, @($attribute, $kosType))
        }
    }
}
$shared = New-Object kOS.Safe.SafeSharedObjects
$functions = New-Object kOS.Safe.Function.FunctionManager($shared)
$functions.Load()
if (-not $functions.Exists('max')) { throw 'Safe function registration failed' }
$options = New-Object kOS.Safe.Compilation.CompilerOptions
$options.FuncManager = $functions
$options.AllowClobberBuiltins = $false
$options.IsCalledFromRun = $true
$options.LoadProgramsInSameAddressSpace = $true
# Confirm that this compiler really rejects protected safe function names.
$rejected = $false
try {
    $compiler = New-Object kOS.Safe.Compilation.KS.KSScript
    $null = $compiler.Compile([kOS.Safe.Persistence.GlobalPath]::FromString('0:/collision.ks'),
        1, 'local max is 1.', 'collision', $options)
} catch { $rejected = $true }
if (-not $rejected) { throw 'Compiler did not enforce builtin protection' }
foreach ($relative in @('Libraries/lib_aerosim.ks',
    'Libraries/Poseidon_SSTO/entry_guid.ks',
    'Libraries/Poseidon_SSTO/terminal_route.ks',
    'Libraries/Poseidon_SSTO/craft_Poseidon_SSTO.ks',
    'Libraries/Poseidon_SSTO/flight_log.ks', 'Poseidon_SSTO/Poseidon_SSTO_Reentry.ks')) {
    $compiler = New-Object kOS.Safe.Compilation.KS.KSScript
    $text = [IO.File]::ReadAllText((Join-Path (Get-Location) ('Script/' + $relative)))
    $parts = $compiler.Compile([kOS.Safe.Persistence.GlobalPath]::FromString('0:/' + $relative),
        1, $text, $relative, $options)
    Write-Output ('PASS compile: ' + $relative + ' parts=' + $parts.Count)
}
