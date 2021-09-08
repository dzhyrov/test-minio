#!/usr/bin/python3

"""

Parse kubeflow JSON configuration files and extract docker images

Usage:

./kube_parse.py file_name.json

"""
import sys
import re
import json

from json.decoder import JSONDecodeError

IMAGE_KEY = 'image'


def find_images(fname):
    found = 0
    with open(fname) as txt:
        for l in txt.readlines():
            m = re.search('image', l)
            if m:
                found += 1
                print(l)
    print("Found images[{0}]: {1}".format(fname, found))


def parse_json_images(search_key, text_data):
    if text_data is not None and type(text_data) == str:
        m = re.search(search_key, text_data)
        if m:
            try:
                j = json.loads(text_data)
                if type(j) == dict:
                    im = extract_images_recursively(j)
                    return im
            except json.JSONDecodeError:
                #
                # Try to parse YAML section
                #
                ym = re.search(r'image:\s+([a-zA-Z]+.*)', text_data)
                if ym:
                    img = ym.group(1)
                    return [img]
    return ''


def concat_image_name_with_tag(inp_dict, value):
    """
    Concatenate image name with tag if `value` has no ':' symbol inside
    :param inp_dict:
    :param text value:
    :return: list array
    """
    if not re.search(':', value):  # Image has no tag
        res_values = []
        if 'defaultImageVersion' in inp_dict:
            res_values.append('{0}:{1}'.format(value, inp_dict['defaultImageVersion']))
        if 'defaultGpuImageVersion' in inp_dict:
            res_values.append('{0}:{1}'.format(value, inp_dict['defaultGpuImageVersion']))
        return res_values

    return [value]


def extract_images_recursively(inp_dict):
    images = []

    if type(inp_dict) != dict:
        return []

    for key, value in inp_dict.items():
        if type(value) == list:
            for v1 in value:
                images += extract_images_recursively(v1)
        elif type(value) == dict:
            for k2, v2 in value.items():
                if type(v2) == dict:
                    images += extract_images_recursively(v2)
                else:
                    if k2 == 'image':
                        images += concat_image_name_with_tag(value, v2)
                    else:
                        # Parse inline JSON code block
                        images += parse_json_images(IMAGE_KEY, v2)
        elif type(value) == str:
            if key == 'image':
                images += concat_image_name_with_tag(inp_dict, value)
            else:
                # Parse inline JSON code block
                images += parse_json_images(IMAGE_KEY, value)
        else:
            # Do not processing unhandled value types, like bool, None, etc
            pass

    return images


def process_json_file(json_file):
    uniq_images = []
    with open(json_file) as fp:
        try:
            json_data = json.load(fp)
            images = extract_images_recursively(json_data)
            uniq_images = list(dict.fromkeys(images))
        except JSONDecodeError:
            pass
        except UnicodeDecodeError:
            pass

    return uniq_images


def txt_images():
    imgs = []
    with open('images.txt') as img:
        for ln in img:
            arr = ln.strip().split()
            if len(arr):
                imgs.append(arr[1])
    return imgs


def main(fpath):
    cm_images = process_json_file(fpath)
    for img in cm_images:
        print(img)


if __name__ == '__main__':
    #
    # Examples:
    #
    # find_images('kubeflow_descr.txt')
    # find_images('kubeflow_descr.json')
    # for fl in os.listdir('.'):
    #    process_json_file(fl)

    # tx_images = txt_images()

    # cross = 0
    # for cm in tx_images:
    #     if cm in cm_images:
    #         cross += 1
    # print(f'Crossed: {cross}')
    # for img in sorted(tx_images + cm_images):
    #     print(img)

    # print(len(tx_images), sorted(tx_images))
    # print(len(cm_images), sorted(cm_images))

    main(sys.argv[1])
