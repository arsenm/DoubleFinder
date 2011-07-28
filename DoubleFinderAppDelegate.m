/*
 * Copyright (C) 2011 Matthew Arsenault <arsenm2@rpi.edu>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 */

#import "DoubleFinderAppDelegate.h"
#import <OpenCL/OpenCL.h>

@implementation DoubleFinderAppDelegate

@synthesize window;

static cl_device_id* _devices = NULL;
static cl_bool* _deviceDoubles = NULL;
static cl_device_type* _deviceTypes = NULL;
static NSString** _deviceNames = NULL;
static cl_uint _nDevices = 0;


static NSString* deviceName(cl_device_id dev)
{
    cl_int err;
    char name[256];
    size_t readSize;

    err = clGetDeviceInfo(dev, CL_DEVICE_NAME, sizeof(name), name, &readSize);
    if (err != CL_SUCCESS)
    {
        [NSException raise:@"Failed to get device extensions" format:@"err = %d", err];
    }

    return [[NSString alloc] initWithUTF8String:name];
}

static cl_device_type deviceType(cl_device_id dev)
{
    cl_int err;
    cl_device_type type;

    err = clGetDeviceInfo(dev, CL_DEVICE_TYPE, sizeof(type), &type, NULL);
    if (err != CL_SUCCESS)
    {
        [NSException raise:@"Failed to get device type" format:@"err = %d", err];
    }

    return type;
}

static cl_bool deviceHasDoubles(cl_device_id dev)
{
    char exts[4096];
    size_t readSize;
    cl_int err;
    char* khr_fp64;

    // CL_DEVICE_DOUBLE_FP_CONFIG
    // I'm not sure what this does if there is no double extension
    // is it 0? Or what


    err = clGetDeviceInfo(dev, CL_DEVICE_EXTENSIONS, sizeof(exts), exts, &readSize);
    if (err != CL_SUCCESS)
    {
        [NSException raise:@"Failed to get device extensions" format:@"err = %d", err];
    }

    if (readSize >= sizeof(exts))
    {
        [NSException raise:@"Extensions too large" format:@"Read size = %zu", readSize];
    }

    khr_fp64 = strnstr(exts, "cl_khr_fp64", sizeof(exts));

    return (khr_fp64 != NULL);
}

static cl_device_id* getDeviceIds(cl_uint* nDevOut)
{
    cl_platform_id platform;
    cl_uint nPlat, nDev;
    cl_int err;
    cl_device_id* devs;

    err = clGetPlatformIDs(0, NULL, &nPlat);
    if (err != CL_SUCCESS)
    {
        [NSException raise:@"Failed to get platform IDs" format:@"err = %d", err];
    }

    if (nPlat == 0)
    {
        [NSException raise:@"No platforms found" format:@"nPlat = %d", nPlat];
    }

    clGetPlatformIDs(1, &platform, NULL);
    if (err != CL_SUCCESS)
    {
        [NSException raise:@"Failed to get platform ID" format:@"err = %d", err];
    }

    err = clGetDeviceIDs(platform, CL_DEVICE_TYPE_ALL, 0, NULL, &nDev);
    if (err != CL_SUCCESS)
    {
        [NSException raise:@"Failed to get device ID count" format:@"err = %d", err];
    }

    if (nDev == 0)
    {
        [NSException raise:@"No devices found" format:@"nPlat = %d", nDev];
    }

    devs = malloc(nDev * sizeof(cl_device_id));
    if (!devs)
    {
        perror("Allocating device ids");
        exit(EXIT_FAILURE);
    }

    err = clGetDeviceIDs(platform, CL_DEVICE_TYPE_ALL, nDev, devs, NULL);
    if (err != CL_SUCCESS)
    {
        [NSException raise:@"Failed to get device IDs" format:@"err = %d", err];
    }

    if (nDevOut)
    {
        *nDevOut = nDev;
    }

    return devs;
}

- (void) applicationDidFinishLaunching:(NSNotification*) aNotification
{
    cl_uint i;

    _devices = getDeviceIds(&_nDevices);

    _deviceDoubles = calloc(_nDevices, sizeof(cl_bool));
    if (!_deviceDoubles)
    {
        perror("Allocating deviceDoubles");
        exit(EXIT_FAILURE);
    }

    _deviceNames = calloc(_nDevices, sizeof(NSString*));
    if (!_deviceNames)
    {
        perror("Allocating names");
        exit(EXIT_FAILURE);
    }

    _deviceTypes = calloc(_nDevices, sizeof(cl_device_type));
    if (!_deviceTypes)
    {
        perror("Allocating device type");
        exit(EXIT_FAILURE);
    }

    for (i = 0; i < _nDevices; ++i)
    {
        _deviceDoubles[i] = deviceHasDoubles(_devices[i]);
        _deviceNames[i] = deviceName(_devices[i]);
        _deviceTypes[i] = deviceType(_devices[i]);
    }

    [tableView reloadData];
}

- (void)applicationWillTerminate:(NSNotification*) aNotification
{
    printf("Will terminate\n");

    free(_devices);
    free(_deviceDoubles);
    free(_deviceNames);
    free(_deviceTypes);
    _devices = NULL;
    _deviceDoubles = NULL;
    _deviceNames = NULL;
    _deviceTypes = NULL;
    _nDevices = 0;
}

- (NSInteger) numberOfRowsInTableView:(NSTableView*) aTableView
{
    return (NSInteger) _nDevices;
}

- (id) tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*) column row:(NSInteger)rowIndex
{
    static NSAttributedString * noDoublesString = nil;
    static NSAttributedString * cpuString = nil;
    static NSAttributedString * doublesString = nil;
    static NSAttributedString * mysteryDoublesString = nil;

    if(noDoublesString == nil)
    {
        NSDictionary * redAttribute, * greenAttribute, * orangeAttribute;;

        redAttribute = [NSDictionary dictionaryWithObject:[NSColor redColor]
                                                   forKey:NSForegroundColorAttributeName];
        greenAttribute = [NSDictionary dictionaryWithObject:[NSColor greenColor]
                                                     forKey:NSForegroundColorAttributeName];
        orangeAttribute = [NSDictionary dictionaryWithObject:[NSColor orangeColor]
                                                      forKey:NSForegroundColorAttributeName];

        noDoublesString = [[NSAttributedString alloc] initWithString:@"NO DOUBLES" attributes:redAttribute];
        cpuString = [[NSAttributedString alloc] initWithString:@"Doubles, but a CPU so not interesting" attributes:orangeAttribute];
        doublesString = [[NSAttributedString alloc] initWithString:@"A quality device with a nonbroken OpenCL" attributes:greenAttribute];
        mysteryDoublesString = [[NSAttributedString alloc] initWithString:@"A MYSTERY device with a nonbroken OpenCL" attributes:orangeAttribute];
    }


    if (rowIndex >= _nDevices)
        return nil;

    if ([[column identifier] isEqualToString:@"DeviceColumn"])
    {
        return _deviceNames[rowIndex];
    }
    else if ([[column identifier] isEqualToString:@"DoubleColumn"])
    {
        if (!_deviceDoubles[rowIndex])
        {
            return noDoublesString;
        }

        switch (_deviceTypes[rowIndex])
        {
            case CL_DEVICE_TYPE_CPU:
                return cpuString;
            case CL_DEVICE_TYPE_ACCELERATOR:
            case CL_DEVICE_TYPE_GPU:
                return doublesString;
            default:
                return mysteryDoublesString;
        }
    }

    return nil;
}

@end


