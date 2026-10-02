#[[
This source file is part of the Swift System open source project

Copyright (c) 2020 - 2026 Apple Inc. and the Swift System project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

add_library(SystemPackage
  Errno.swift
  ErrnoWindows.swift
  FileControl.swift
  FileControlCommand.swift
  FileControlTypes.swift
  FileDescriptor.swift
  FileHelpers.swift
  FileLock.swift
  FileOperations.swift
  FilePermissions.swift
  MachPort.swift
  OwnedFD.swift
  PlatformString.swift
  ProcessID.swift
  ResourceUsageInfo.swift
  SystemConfig.swift
  SystemString.swift
  TaskInfo.swift
  UserDatabase.swift
  Util.swift
  Util+StringArray.swift
  UtilConsumers.swift
  WinSDK+Overlay.swift)
set_target_properties(SystemPackage PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_Swift_MODULE_DIRECTORY})

# Availability macro definitions.
# Should stay in sync with the `availability` array in Package.swift,
# matching `sourceAvailability`, which is the minimum Swift availability.
# Availability support for Darwin platforms is omitted.
set(SWIFT_SYSTEM_AVAILABILITY_VERSIONS
  0.0.1 0.0.2 0.0.3
  1.1.0 1.1.1 1.2.0 1.2.1 1.3.0 1.3.1 1.3.2 1.4.0
  1.7.0
  199)
set(SWIFT_SYSTEM_SOURCE_AVAILABILITY
  "macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, visionOS 1.0")
set(SWIFT_SYSTEM_AVAILABILITY_MACRO)
foreach(version IN LISTS SWIFT_SYSTEM_AVAILABILITY_VERSIONS)
  list(APPEND SWIFT_SYSTEM_AVAILABILITY_MACRO
    "SHELL:-enable-experimental-feature \"AvailabilityMacro=System ${version}:${SWIFT_SYSTEM_SOURCE_AVAILABILITY}\"")
endforeach()

target_compile_options(SystemPackage PRIVATE
  -enable-experimental-feature Lifetimes
  ${SWIFT_SYSTEM_AVAILABILITY_MACRO}
  "SHELL:-package-name swift-system")
target_sources(SystemPackage PRIVATE
  AttributeLists/Attribute.swift
  AttributeLists/Attributes.swift
  AttributeLists/GetAttributes.swift
  AttributeLists/VolumeCapabilities.swift
  Internals/Constants+AttributeLists.swift
  Internals/Syscalls+AttributeLists.swift)
target_sources(SystemPackage PRIVATE
  BrokenDownTime/BrokenDownTime.swift
  Internals/Syscalls+BrokenDownTime.swift)
target_sources(SystemPackage PRIVATE
  ClockTime/ClockTime.swift)
target_sources(SystemPackage PRIVATE
  Directories/CInterop+DirectoryEntry.swift
  Directories/DirectoryStream.swift
  Directories/DirectoryWalk.swift)
target_sources(SystemPackage PRIVATE
  DirectoryEntryTypes/FileType+DirectoryEntry.swift)
target_sources(SystemPackage PRIVATE
  DynamicLoading/DynamicLibrary.swift)
target_sources(SystemPackage PRIVATE
  DynamicLoading/LoadedImages.swift
  Internals/Syscalls+LoadedImages.swift)
target_sources(SystemPackage PRIVATE
  Entropy/Entropy.swift)
target_sources(SystemPackage PRIVATE
  Environment/ProcessEnvironment.swift)
target_sources(SystemPackage PRIVATE
  Errno/ErrnoAccess.swift)
target_sources(SystemPackage PRIVATE
  Events/EventCounter.swift
  Events/EventPoll.swift
  Events/FileWatcher.swift
  Events/IntervalTimer.swift
  Events/KernelEvent.swift
  Events/KernelQueue.swift
  Events/Poll.swift
  Events/Timeouts.swift)
target_sources(SystemPackage PRIVATE
  Executable/CurrentExecutable.swift
  Internals/Syscalls+Executable.swift)
target_sources(SystemPackage PRIVATE
  ExitCodes/ExitCode.swift
  Internals/Constants+ExitCodes.swift)
target_sources(SystemPackage PRIVATE
  ExtendedAttributes/ExtendedAttributes.swift)
target_sources(SystemPackage PRIVATE
  FileCopying/FileClone.swift
  FileCopying/FileContentsClone.swift
  FileCopying/FileCopy.swift
  FileCopying/FileCopyState.swift
  Internals/Constants+FileCopying.swift
  Internals/Syscalls+FileContentsClone.swift
  Internals/Syscalls+FileCopying.swift)
target_sources(SystemPackage PRIVATE
  FilePath/FilePath.swift
  FilePath/FilePathComponents.swift
  FilePath/FilePathComponentView.swift
  FilePath/FilePathParsing.swift
  FilePath/FilePathString.swift
  FilePath/FilePathSyntax.swift
  FilePath/FilePathTemp.swift
  FilePath/FilePathTempPosix.swift
  FilePath/FilePathTempWindows.swift
  FilePath/FilePathWindows.swift)
target_sources(SystemPackage PRIVATE
  FileRemoval/RemoveProgress.swift
  FileRemoval/RemoveRecursively.swift
  Internals/Constants+FileRemoval.swift
  Internals/Syscalls+FileRemoval.swift)
target_sources(SystemPackage PRIVATE
  FileSystem/DiskQuota.swift
  FileSystem/FileFlags.swift
  FileSystem/FileMode.swift
  FileSystem/FilePathOperations.swift
  FileSystem/FileSystemType+Linux.swift
  FileSystem/FileTimes.swift
  FileSystem/FileType.swift
  FileSystem/Identifiers.swift
  FileSystem/MountFlags.swift
  FileSystem/Stat.swift
  FileSystem/StatFS.swift)
if(CMAKE_SYSTEM_NAME STREQUAL Linux)
  target_sources(SystemPackage PRIVATE
    IORing/IOCompletion.swift
    IORing/IORequest.swift
    IORing/IORing.swift
    IORing/IORing+Util.swift
    IORing/PollEvents.swift
    IORing/RawIORequest.swift)
endif()
target_sources(SystemPackage PRIVATE
  Internals/Backcompat.swift
  Internals/CInterop+Accessors.swift
  Internals/CInterop+Offset.swift
  Internals/CInterop.swift
  Internals/Constants+DynamicLoading.swift
  Internals/Constants+Events.swift
  Internals/Constants+ExtendedAttributes.swift
  Internals/Constants+FileWatcher.swift
  Internals/Constants+MemoryMapping.swift
  Internals/Constants+NetworkInterfaces.swift
  Internals/Constants+StatFS.swift
  Internals/Constants+Time.swift
  Internals/Constants.swift
  Internals/Exports.swift
  Internals/Mocking.swift
  Internals/RawBuffer.swift
  Internals/Syscalls+Directories.swift
  Internals/Syscalls+DynamicLoading.swift
  Internals/Syscalls+Entropy.swift
  Internals/Syscalls+Environment.swift
  Internals/Syscalls+Events.swift
  Internals/Syscalls+ExtendedAttributes.swift
  Internals/Syscalls+FileWatcher.swift
  Internals/Syscalls+MemoryMapping.swift
  Internals/Syscalls+NetworkInterfaces.swift
  Internals/Syscalls+PathsAndFiles.swift
  Internals/Syscalls+StatFS.swift
  Internals/Syscalls+SystemIdentity.swift
  Internals/Syscalls+Time.swift
  Internals/Syscalls+VectoredIO.swift
  Internals/Syscalls.swift
  Internals/WindowsSyscallAdapters.swift)
target_sources(SystemPackage PRIVATE
  Internals/Constants+LibProc.swift
  Internals/Syscalls+LibProc.swift
  LibProc/BSDInfo.swift
  LibProc/OpenFileDescriptors.swift
  LibProc/ProcessList.swift
  LibProc/ProcessPaths.swift)
target_sources(SystemPackage PRIVATE
  Internals/Constants+Limits.swift
  Limits/CompileTimeLimits+Pipes.swift
  Limits/CompileTimeLimits.swift)
target_sources(SystemPackage PRIVATE
  MachCPU/MachCPUType.swift)
target_sources(SystemPackage PRIVATE
  Internals/Syscalls+MachTime.swift
  MachTime/MachTime.swift)
target_sources(SystemPackage PRIVATE
  Internals/Constants+MachVirtualMemory.swift
  Internals/Syscalls+MachVirtualMemory.swift
  MachVirtualMemory/MachKernelError.swift
  MachVirtualMemory/MachVirtualMemory.swift)
target_sources(SystemPackage PRIVATE
  Internals/Constants+Memory.swift
  Internals/Syscalls+Memory.swift
  Memory/Memory.swift
  Memory/MemoryAllocator.swift
  Memory/MemoryBytes.swift
  Memory/MemoryZone.swift)
target_sources(SystemPackage PRIVATE
  MemoryMapping/MemoryMapping.swift)
target_sources(SystemPackage PRIVATE
  Internals/Constants+MemoryLocking.swift
  Internals/Syscalls+MemoryLocking.swift
  MemoryLocking/MemoryLocking.swift)
target_sources(SystemPackage PRIVATE
  NetworkInterfaces/NetworkInterface.swift)
target_sources(SystemPackage PRIVATE
  Internals/Constants+Passphrase.swift
  Passphrase/ReadPassphrase.swift)
target_sources(SystemPackage PRIVATE
  PathsAndFiles/FilePath+Resolution.swift
  PathsAndFiles/PathOnlyDescriptors.swift
  PathsAndFiles/ProcessDefaults.swift
  PathsAndFiles/UniqueFiles.swift)
target_sources(SystemPackage PRIVATE
  Internals/Syscalls+ProcessCredentials.swift
  ProcessCredentials/ProcessCredentials.swift)
target_sources(SystemPackage PRIVATE
  Internals/Syscalls+ProcessExit.swift
  ProcessExit/ProcessExit.swift)
target_sources(SystemPackage PRIVATE
  Internals/Constants+Processes.swift
  Internals/Syscalls+Processes.swift
  Processes/ChildProcess.swift
  Processes/CInterop+Processes.swift
  Processes/CloseDescriptors.swift
  Processes/Credentials.swift
  Processes/ExitStatus.swift
  Processes/ProcessDescriptor.swift
  Processes/ProcessGroups.swift
  Processes/ProcessWait.swift
  Processes/ResourceLimits.swift
  Processes/Signal.swift
  Processes/SignalAction.swift
  Processes/SignalDescriptor.swift
  Processes/SignalSending.swift
  Processes/SignalSet.swift
  Processes/Spawn.swift)
target_sources(SystemPackage PRIVATE
  Internals/Constants+Provisional.swift
  Internals/Syscalls+Provisional.swift
  Internals/Syscalls+ProvisionalLocale.swift
  Internals/Syscalls+ProvisionalMath.swift
  Provisional/Provisional+CType.swift
  Provisional/Provisional+Execinfo.swift
  Provisional/Provisional+Locale.swift
  Provisional/Provisional+Math.swift
  Provisional/Provisional+POSIXErrorCode.swift
  Provisional/Provisional+Stdio.swift
  Provisional/Provisional+StringH.swift)
target_sources(SystemPackage PRIVATE
  Internals/Syscalls+Pseudoterminals.swift
  Pseudoterminals/Pseudoterminal.swift)
target_sources(SystemPackage PRIVATE
  RandomGenerator/RandomGenerator.swift)
target_sources(SystemPackage PRIVATE
  RawSpawn/RawSpawn.swift)
target_sources(SystemPackage PRIVATE
  Internals/Syscalls+RootAndSync.swift
  RootAndSync/RootAndSync.swift)
target_sources(SystemPackage PRIVATE
  Internals/Constants+SearchPaths.swift
  Internals/Syscalls+SearchPaths.swift
  SearchPaths/SearchPaths.swift)
target_sources(SystemPackage PRIVATE
  Internals/Syscalls+SendFile.swift
  SendFile/SendFile.swift)
target_sources(SystemPackage PRIVATE
  Internals/Constants+SharedMemory.swift
  Internals/Syscalls+SharedMemory.swift
  SharedMemory/NamedSemaphore.swift
  SharedMemory/SharedMemory.swift)
target_sources(SystemPackage PRIVATE
  SignalMessages/SignalMessage.swift)
target_sources(SystemPackage PRIVATE
  Internals/Syscalls+SpawnCredentials.swift
  SpawnCredentials/SpawnCredentials.swift)
target_sources(SystemPackage PRIVATE
  SynchronizedIO/SynchronizedIO.swift)
target_sources(SystemPackage PRIVATE
  Internals/Constants+SystemControl.swift
  Internals/Syscalls+SystemControl.swift
  SystemControl/SystemControl.swift
  SystemControl/SystemControlNames.swift
  SystemControl/SystemControlProcessInfo.swift)
target_sources(SystemPackage PRIVATE
  SystemIdentity/SystemIdentity.swift)
target_sources(SystemPackage PRIVATE
  Internals/Constants+SystemPaths.swift
  Internals/Syscalls+SystemPaths.swift
  SystemPaths/ConfigurationStrings.swift
  SystemPaths/MakePath.swift)
target_sources(SystemPackage PRIVATE
  Internals/Syscalls+SmallGaps.swift
  TemporaryFiles/UniqueFilesWithPermissions.swift
  TemporaryFiles/UniqueFilesWithSuffix.swift
  TemporaryFiles/UnnamedTemporaryFiles.swift)
target_sources(SystemPackage PRIVATE
  Terminal/BaudRate.swift
  Terminal/ControlCharacters.swift
  Terminal/TerminalAttributes.swift
  Terminal/TerminalAttributes+Serial.swift
  Terminal/TerminalDescriptor.swift
  Terminal/TerminalFlags.swift
  Terminal/TerminalJobControl.swift
  Terminal/TerminalOperations.swift
  Terminal/TerminalWindowSize.swift)
target_sources(SystemPackage PRIVATE
  Internals/Constants+Threads.swift
  Internals/Syscalls+ThreadCancellation.swift
  Internals/Syscalls+Threads.swift
  Threads/CInterop+Threads.swift
  Threads/PThread.swift
  Threads/PThreadAttributes.swift
  Threads/PThreadCancellation.swift
  Threads/PThreadCondition.swift
  Threads/PThreadCPUSet.swift
  Threads/PThreadID.swift
  Threads/PThreadKey.swift
  Threads/PThreadMutex.swift
  Threads/PThreadNames.swift
  Threads/PThreadReadWriteLock.swift
  Threads/PThreadScheduling.swift
  Threads/PThreadStaticInitializers.swift)
target_sources(SystemPackage PRIVATE
  Time/ClockID.swift
  Time/Sleep.swift)
target_sources(SystemPackage PRIVATE
  TimeZoneFiles/TimeZoneFiles.swift)
target_sources(SystemPackage PRIVATE
  Internals/Constants+TimersAndPriority.swift
  Internals/Syscalls+TimersAndPriority.swift
  TimersAndPriority/IOPolicy.swift
  TimersAndPriority/ProcessPriority.swift
  TimersAndPriority/ProcessTimer.swift)
target_sources(SystemPackage PRIVATE
  Internals/Constants+TypedAllocation.swift
  Internals/Syscalls+TypedAllocation.swift
  TypedAllocation/TypeDescriptor.swift
  TypedAllocation/TypedAllocation.swift)
target_sources(SystemPackage PRIVATE
  Internals/Syscalls+UnfairLockAndRandom.swift
  UnfairLock/UnfairLock.swift)
target_sources(SystemPackage PRIVATE
  VectoredIO/VectoredIO.swift)
target_sources(SystemPackage PRIVATE
  Win32/DynamicLibraryWindows.swift
  Win32/PathsWindows.swift
  Win32/ProcessEnvironmentWindows.swift
  Win32/ProcessIDWindows.swift
  Win32/Win32.swift
  Win32/Win32Console.swift
  Win32/Win32Constants.swift
  Win32/Win32Error.swift
  Win32/Win32FileDescriptorBridge.swift
  Win32/Win32FileHandle.swift
  Win32/Win32FileIO.swift
  Win32/Win32FileInformation.swift
  Win32/Win32FileType.swift
  Win32/Win32FinalPath.swift
  Win32/Win32HandleOperations.swift
  Win32/Win32Locking.swift
  Win32/Win32Open.swift
  Win32/Win32Process.swift
  Win32/Win32ProcessCreation.swift
  Win32/Win32SecurityDescriptor.swift
  Win32/Win32Synchronization.swift
  Win32/Win32Syscalls.swift
  Win32/Win32Thread.swift
  Win32/Win32Time.swift
  Win32/Win32VolumeInformation.swift
  Win32/Win32Wait.swift)
target_link_libraries(SystemPackage PUBLIC
  CSystem)

set(SWIFT_SYSTEM_APPLE_PLATFORMS "Darwin" "iOS" "watchOS" "tvOS" "visionOS")
if(CMAKE_SYSTEM_NAME IN_LIST SWIFT_SYSTEM_APPLE_PLATFORMS)
  target_compile_definitions(SystemPackage PRIVATE SYSTEM_PACKAGE_DARWIN)
endif()

_install_target(SystemPackage)
set_property(GLOBAL APPEND PROPERTY SWIFT_SYSTEM_EXPORTS SystemPackage)
